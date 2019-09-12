#!/usr/bin/env sh

builds=\
"10.10_10.10-r0_3.8",\
"10_10.10-r0_3.8",\
"latest_10.10-r0_3.8"

for build in $(echo $builds | tr ',' '\n'); do
  tag=$(echo "${build}" | cut -d '_' -f 1 )
  pg_version=$(echo "${build}" | cut -d '_' -f 2)
  pg_alpine_branch=$(echo "${build}" | cut -d '_' -f 3)

  echo docker build --tag bluedrop360/postgres-restore-from-s3:"${tag}" --build-arg pg_version="${pg_version}" --build-arg pg_alpine_branch="${pg_alpine_branch}" .
  eval docker build --tag bluedrop360/postgres-restore-from-s3:"${tag}" --build-arg pg_version="${pg_version}" --build-arg pg_alpine_branch="${pg_alpine_branch}" .
  echo docker push bluedrop360/postgres-restore-from-s3:"${tag}"
  eval docker push bluedrop360/postgres-restore-from-s3:"${tag}"
done
