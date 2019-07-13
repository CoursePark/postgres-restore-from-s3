#!/usr/bin/env sh

################################################################
# Variable definitions
################################################################
# shellcheck disable=SC2001
db_name=$(echo "${DATABASE_URL}" | sed "s|.*/\([^/]*\)\$|\\1|")

# shellcheck disable=SC2001
db_root_url=$(echo "${DATABASE_URL}" | sed "s|/[^/]*\$|/template1|")

drop_result=$(echo "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '${db_name}'; \
DROP DATABASE ${db_name};" | psql "${db_root_url}" 2>&1)

################################################################
# Locate the dump file in the cache or from AWS S3
################################################################
printf '%b\n' "\n> Searching for a dump file in the local cache..."

if [ -n "$DUMP_OBJECT" ]; then
    object=${DUMP_OBJECT}
    dump_file=$(echo "${DUMP_OBJECT}" | sed 's/.*\///')
else
    if [ -n "$DUMP_OBJECT_DATE" ]; then
        filter=${DUMP_OBJECT_DATE}
    else
        filter=$(date +"%Y-%m-%dT%H:%M")
    fi

    # Broaden filter until a match is found that is also less than filter
    while true; do
        printf '%b\n' "    Trying filter: ${filter}"
        
        # File exists in the cache, stop looking remotely
        if [ -f "/cache/$filter.dump" ]; then
            object=${filter}
            dump_file=${filter}.dump
            break;
        fi

        dump_file=$(aws --region "${AWS_REGION}" s3 ls "s3://${AWS_BUCKET}/${DUMP_OBJECT_PREFIX}${filter}" | sed "s/.* //" | grep '^[0-9:T\-]\{16\}\.dump$' | sort | tail -n 1)

        # Found an object, success
        if [ -n "${dump_file}" ]; then
            object=${DUMP_OBJECT_PREFIX}${dump_file}
            break;
        fi

        # Got to an empty filter and still nothing found
        if [ -z "$filter" ]; then
            object=""
            break;
        fi
        
        filter="${filter%?}"
    done
fi

if [ -z "$object" ]; then
    printf '%b\n' "> Dump file not found in AWS S3 bucket"
    exit 1
fi

if [ -f "/cache/${dump_file}" ]; then
    printf '%b\n' "    Using cached dump: \"${dump_file}\""
else
    printf '%b\n' "    Not found: Attempting to download the dump from an AWS S3 bucket"

    # Download the dump
    printf '%b\n' "\n> Downloading the latest dump from: \"s3://${AWS_BUCKET}/${DUMP_OBJECT_PREFIX}\""
    aws --region "${AWS_REGION}" s3 cp "s3://${AWS_BUCKET}/${object}" "/cache/${dump_file}" || exit 1
fi

################################################################
# Drop the target database
################################################################
printf '%b\n' '\n> Dropping the target database...'
printf '%b\n' "    DROP DATABASE ${db_name};"

if echo "${drop_result}" | grep "other session using the database" >/dev/null 2>&1; then
    echo "RESTORE FAILED - another database session is preventing drop of database ${db_name}"
    exit 1
fi

################################################################
# Restore the target database
################################################################
printf '%b\n' '\n> Restoring the target database...'
printf '%b\n' "    CREATE DATABASE ${db_name};\n    REVOKE connect ON DATABASE ${db_name} FROM PUBLIC;\n    ALTER DATABASE ${db_name} OWNER TO ${db_name};"

printf '%s' \
"CREATE DATABASE ${db_name}; REVOKE connect ON DATABASE ${db_name} FROM PUBLIC; ALTER DATABASE ${db_name} OWNER TO ${db_name};" | \
psql "${db_root_url}" >/dev/null 2>&1

printf '%b\n' "\n> Rebuilding the target database..."

if [ -n "$PRE_RESTORE_PSQL" ]; then
    printf '%b\n' "> Executing pre-restore psql"
    printf '%b\n' "${PRE_RESTORE_PSQL}" | psql "${DATABASE_URL}"
fi

if [ -n "$SCHEMA" ]; then
    printf '%s' "    pg_restore --jobs $(grep -c ^processor /proc/cpuinfo) --schema $SCHEMA --no-owner -d <DATABASE_URL> /cache/${dump_file}"
    pg_restore --jobs "$(grep -c ^processor /proc/cpuinfo)" --schema "$SCHEMA" --no-owner -d "${DATABASE_URL}" "/cache/${dump_file}"
else
    printf '%s' "    pg_restore --jobs $(grep -c ^processor /proc/cpuinfo) --no-owner -d <DATABASE_URL> /cache/${dump_file}"
    pg_restore --jobs "$(grep -c ^processor /proc/cpuinfo)" --no-owner -d "${DATABASE_URL}" "/cache/${dump_file}"
fi

if [ -n "$POST_RESTORE_PSQL" ]; then
    printf '%b\n' "> Executing post-restore psql"
    printf '%s' "${POST_RESTORE_PSQL}" | psql "${DATABASE_URL}"
fi

echo ""
echo "COMPLETE: ${object}"
