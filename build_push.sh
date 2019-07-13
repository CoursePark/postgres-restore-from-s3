#!/usr/bin/env sh

builds=$(echo '
9.6.10    9.6.10-r0   3.6
9.6       9.6.10-r0   3.6
9         9.6.10-r0   3.6
latest    9.6.10-r0   3.6
' | grep -v '^#' | tr -s ' ')

# shellcheck disable=SC2039
IFS=$'\n'
for build in $builds; do
  TAG=$(echo "${build}" | cut -d ' ' -f 1 )
  pg_version=$(echo "${build}" | cut -d ' ' -f 2)
  pg_alpine_version=$(echo "${build}" | cut -d ' ' -f 3)

  echo docker build --tag bluedrop360/postgres-restore-from-s3:"${tag}" --build-arg pg_version="${pg_version}" --build-arg pg_alpine_branch="${pg_alpine_version}" .
  eval docker build --tag bluedrop360/postgres-restore-from-s3:"${tag}" --build-arg pg_version="${pg_version}" --build-arg pg_alpine_branch="${pg_alpine_version}" .
  echo docker push bluedrop360/postgres-restore-from-s3:"${tag}"
  eval docker push bluedrop360/postgres-restore-from-s3:"${tag}"
done
