#!/usr/bin/env sh

################################################################
# Variable definitions
################################################################
# shellcheck disable=SC2001
DB_NAME=$(echo "${DATABASE_URL}" | sed "s|.*/\([^/]*\)\$|\\1|")

# shellcheck disable=SC2001
DB_ROOT_URL=$(echo "${DATABASE_URL}" | sed "s|/[^/]*\$|/template1|")

DROP_RESULT=$(echo "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '${DB_NAME}'; \
DROP DATABASE ${DB_NAME};" | psql "${DB_ROOT_URL}" 2>&1)

################################################################
# Locate the dump file in the cache or from AWS S3
################################################################
printf '%b\n' "\n> Searching for a dump file in the local cache..."

if [ -n "$DUMP_OBJECT" ]; then
    OBJECT=${DUMP_OBJECT}
    DUMP_FILE=$(echo "${DUMP_OBJECT}" | sed 's/.*\///')
else
    if [ -n "$DUMP_OBJECT_DATE" ]; then
        FILTER=${DUMP_OBJECT_DATE}
    else
        FILTER=$(date +"%Y-%m-%dT%H:%M")
    fi

    # Broaden filter until a match is found that is also less than FILTER
    while true; do
        printf '%b\n' "    Trying filter: ${FILTER}"
        
        # File exists in the cache, stop looking remotely
        if [ -f "/cache/$FILTER.dump" ]; then
            OBJECT=${FILTER}
            DUMP_FILE=${FILTER}.dump
            break;
        fi

        DUMP_FILE=$(aws --region "${AWS_REGION}" s3 ls "s3://${AWS_BUCKET}/${DUMP_OBJECT_PREFIX}${FILTER}" | sed "s/.* //" | grep '^[0-9:T\-]\{16\}\.dump$' | sort | tail -n 1)

        # Found an object, success
        if [ -n "${DUMP_FILE}" ]; then
            OBJECT=${DUMP_OBJECT_PREFIX}${DUMP_FILE}
            break;
        fi

        # Got to an empty filter and still nothing found
        if [ -z "$FILTER" ]; then
            OBJECT=""
            break;
        fi
        
        FILTER="${FILTER%?}"
    done
fi

if [ -z "$OBJECT" ]; then
    printf '%b\n' "> Dump file not found in AWS S3 bucket"
    exit 1
fi

if [ -f "/cache/${DUMP_FILE}" ]; then
    printf '%b\n' "    Using cached dump: \"${DUMP_FILE}\""
else
    printf '%b\n' "    Not found: Attempting to download the dump from an AWS S3 bucket"

    # Download the dump
    printf '%b\n' "\n> Downloading the latest dump from: \"s3://${AWS_BUCKET}/${DUMP_OBJECT_PREFIX}\""
    aws --region "${AWS_REGION}" s3 cp "s3://${AWS_BUCKET}/${OBJECT}" "/cache/${DUMP_FILE}" || exit 1
fi

################################################################
# Drop the target database
################################################################
printf '%b\n' '\n> Dropping the target database...'
printf '%b\n' "    DROP DATABASE ${DB_NAME};"

if echo "${DROP_RESULT}" | grep "other session using the database" >/dev/null 2>&1; then
    echo "RESTORE FAILED - another database session is preventing drop of database ${DB_NAME}"
    exit 1
fi

################################################################
# Restore the target database
################################################################
printf '%b\n' '\n> Restoring the target database...'
printf '%b\n' "    CREATE DATABASE ${DB_NAME};\n    REVOKE connect ON DATABASE ${DB_NAME} FROM PUBLIC;\n    ALTER DATABASE ${DB_NAME} OWNER TO ${DB_NAME};"

printf '%s' \
"CREATE DATABASE ${DB_NAME}; REVOKE connect ON DATABASE ${DB_NAME} FROM PUBLIC; ALTER DATABASE ${DB_NAME} OWNER TO ${DB_NAME};" | \
psql "${DB_ROOT_URL}" >/dev/null 2>&1

printf '%b\n' "\n> Rebuilding the target database..."

if [ -n "$PRE_RESTORE_PSQL" ]; then
    printf '%b\n' "> Executing pre-restore psql"
    printf '%b\n' "${PRE_RESTORE_PSQL}" | psql "${DATABASE_URL}"
fi

if [ -n "$SCHEMA" ]; then
    printf '%s' "    pg_restore --jobs $(grep -c ^processor /proc/cpuinfo) --schema $SCHEMA --no-owner -d <DATABASE_URL> /cache/${DUMP_FILE}"
    pg_restore --jobs "$(grep -c ^processor /proc/cpuinfo)" --schema "$SCHEMA" --no-owner -d "${DATABASE_URL}" "/cache/${DUMP_FILE}"
else
    printf '%s' "    pg_restore --jobs $(grep -c ^processor /proc/cpuinfo) --no-owner -d <DATABASE_URL> /cache/${DUMP_FILE}"
    pg_restore --jobs "$(grep -c ^processor /proc/cpuinfo)" --no-owner -d "${DATABASE_URL}" "/cache/${DUMP_FILE}"
fi

if [ -n "$POST_RESTORE_PSQL" ]; then
    printf '%b\n' "> Executing post-restore psql"
    printf '%s' "${POST_RESTORE_PSQL}" | psql "${DATABASE_URL}"
fi

echo ""
echo "COMPLETE: ${OBJECT}"
