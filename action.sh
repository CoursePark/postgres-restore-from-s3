#!/bin/sh

echo "postgres restore from s3 - finding dump on s3 - s3://${AWS_BUCKET}/${DUMP_OBJECT_PREFIX}"
if [ -n "${DUMP_OBJECT}" ]; then
  object=${DUMP_OBJECT}
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
    object=$(echo -e "$objectSet\n$afterDateFilter" | sort | sed "/$afterDateFilter/q" | sed '/^$/d' | tail -n 2 | head -n 1)
    if [ "$object" != "$afterDateFilter" ]; then
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
  tempFile=$(mktemp -u)
  echo "postgres restore from s3 - downloading dump from s3 - $object"
  aws --region ${AWS_REGION} s3 cp s3://${AWS_BUCKET}/${DUMP_OBJECT_PREFIX}$object $tempFile
  echo "postgres restore from s3 - dropping old database"
  export dbname=`echo $DATABASE_URL | sed "s|.*/\([^/]*\)\$|\\1|"`
  echo "DROP DATABASE $dbname; CREATE DATABASE $dbname;" | psql `echo $DATABASE_URL | sed "s|/[^/]*\$|/template1|"`
  echo "postgres restore from s3 - filling target database with dump"
  pg_restore --no-owner -d $DATABASE_URL $tempFile
  rm $tempFile
  echo "postgres restore from s3 - complete - $object"
else
  echo "postgres restore from s3 - dump file not found on s3"
fi
