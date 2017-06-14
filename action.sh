#!/bin/sh

echo "postgres restore from s3 - finding dump on s3 - s3://${AWS_BUCKET}/${DUMP_OBJECT_PREFIX}"
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
  export dbname=$(echo $DATABASE_URL | sed "s|.*/\([^/]*\)\$|\\1|")
  dbRootUrl=$(echo $DATABASE_URL | sed "s|/[^/]*\$|/template1|")
  drop=$(echo "DROP DATABASE $dbname;" | psql $dbRootUrl 2>&1)
  echo "drop --- " $drop
  create=$(echo "CREATE DATABASE $dbname;" | psql $dbRootUrl 2>&1)
  echo "create --- " $create
  echo "postgres restore from s3 - filling target database with dump"
  if [ -n "$SCHEMA" ]; then
    echo "postgres restore from s3 - schema - $SCHEMA"
    # pg_restore --schema $SCHEMA --no-owner -d $DATABASE_URL /cache/$dumpFile
  else
    echo ""
    # pg_restore --no-owner -d $DATABASE_URL /cache/$dumpFile
  fi
  echo "postgres restore from s3 - complete - $object"
else
  echo "postgres restore from s3 - dump file not found on s3"
fi
