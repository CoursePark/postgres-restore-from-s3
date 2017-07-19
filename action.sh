#!/bin/sh

echo "postgres restore from s3 - looking for dump in cache and on s3 at s3://${AWS_BUCKET}/${DUMP_OBJECT_PREFIX}"
if [ -n "${DUMP_OBJECT}" ]; then
  object=${DUMP_OBJECT}
  dumpFile=$(echo ${DUMP_OBJECT} | sed 's/.*\///')
else
  if [ -n "${DUMP_OBJECT_DATE}" ]; then
    dateFilter=${DUMP_OBJECT_DATE}
  else
    dateFilter=$(date +"%Y-%m-%dT%H:%M")
  fi
  # broaden filter until a match is found that is also less than dateFilter
  filter=$dateFilter
  dumpPattern="\([0-9:T\-]\+\.dump\)"
  while true; do
    echo "postgres restore from s3 - using filter $filter"
    if [ -f "/cache/$filter.dump" ]; then
      # file exists in the cache, stop looking remotely
      object=$filter
      dumpFile=$filter.dump
      break;
    fi
    objectSet=$(aws --region ${AWS_REGION} s3 ls s3://${AWS_BUCKET}/${DUMP_OBJECT_PREFIX}${filter} | sed "s/.* ${dumpPattern}/\1/" | grep "^${dumpPattern}")
    afterDateFilter=${dateFilter}_ # appends a '_' char to ensure ordering after .dump file in the sort
    dumpFile=$(echo -e "$objectSet\n$afterDateFilter" | sort | sed "/$afterDateFilter/q" | sed '/^$/d' | tail -n 2 | head -n 1)
    if [ "$dumpFile" != "$afterDateFilter" ]; then
      object=${DUMP_OBJECT_PREFIX}$dumpFile
      # found an object, success
      break;
    fi
    if [ -z "$filter" ]; then
      # got to an empty filter and still nothing found
      object=""
      break;
    fi
    filter="${filter%?}"
  done
fi
if [ -n "$object" ]; then
  if [ -f "/cache/$dumpFile" ]; then
    echo "postgres restore from s3 - using cached $dumpFile"
  else
    echo "postgres restore from s3 - downloading dump from s3 - $object"
    aws --region ${AWS_REGION} s3 cp s3://${AWS_BUCKET}/$object /cache/$dumpFile
  fi
  echo "postgres restore from s3 - dropping old database"
  dbName=$(echo $DATABASE_URL | sed "s|.*/\([^/]*\)\$|\\1|")
  dbRootUrl=$(echo $DATABASE_URL | sed "s|/[^/]*\$|/template1|")
  dropResult=$(echo "DROP DATABASE $dbName;" | psql $dbRootUrl 2>&1)
  if echo $dropResult | grep "other session using the database" -> /dev/null; then
    echo "RESTORE FAILED - another database session is preventing drop of database $dbName"
    exit 1
  fi
  createResult=$(echo "CREATE DATABASE $dbName;" | psql $dbRootUrl 2>&1)
  echo "postgres restore from s3 - filling target database with dump"
  if [ -n "$PRE_RESTORE_PSQL" ]; then
    echo "postgres restore from s3 - executing pre restore psql"
    printf %s "$PRE_RESTORE_PSQL" | psql $DATABASE_URL
  fi
  if [ -n "$SCHEMA" ]; then
    echo "postgres restore from s3 - schema - $SCHEMA"
    pg_restore --schema $SCHEMA --no-owner -d $DATABASE_URL /cache/$dumpFile
  else
    pg_restore --no-owner -d $DATABASE_URL /cache/$dumpFile
  fi
  if [ -n "$POST_RESTORE_PSQL" ]; then
    echo "postgres restore from s3 - executing post restore psql"
    printf %s "$POST_RESTORE_PSQL" | psql $DATABASE_URL
  fi
  echo "postgres restore from s3 - complete - $object"
else
  echo "postgres restore from s3 - dump file not found on s3"
fi
