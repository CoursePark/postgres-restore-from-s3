#!/usr/bin/env sh

BUILDS=$(echo '
9.6.10    9.6.10-r0   3.6
9.6       9.6.10-r0   3.6
9         9.6.10-r0   3.6
latest    9.6.10-r0   3.6
' | grep -v '^#' | tr -s ' ')

# shellcheck disable=SC2039
IFS=$'\n'
for BUILD in $BUILDS; do
  TAG=$(echo "${BUILD}" | cut -d ' ' -f 1 )
  PG_VERSION=$(echo "${BUILD}" | cut -d ' ' -f 2)
  PG_ALPINE_VERSION=$(echo "${BUILD}" | cut -d ' ' -f 3)

  echo docker build --tag bluedrop360/postgres-restore-from-s3:"${TAG}" --build-arg pg_version="${PG_VERSION}" --build-arg pg_alpine_branch="${PG_ALPINE_VERSION}" .
  eval docker build --tag bluedrop360/postgres-restore-from-s3:"${TAG}" --build-arg pg_version="${PG_VERSION}" --build-arg pg_alpine_branch="${PG_ALPINE_VERSION}" .
  echo docker push bluedrop360/postgres-restore-from-s3:"${TAG}"
  eval docker push bluedrop360/postgres-restore-from-s3:"${TAG}"
done
