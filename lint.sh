#!/usr/bin/env sh

ALLOW_EXTERNAL_SOURCE="${ALLOW_EXTERNAL_SOURCE:-}"

if [ "${1}" = "--yml" ]; then
    printf '\n%s\n' "Checking '.travis.yml'..."
    travis lint ./.travis.yml
fi

if [ "${1}" = "--sh" ]; then
    printf '\n%s\n' "Checking shell scripts..."

    SHELLCHECK_OPTS=""

    RUN_SHELLCHECK="shellcheck ${ALLOW_EXTERNAL_SOURCE} ${SHELLCHECK_OPTS} {} +"
    eval "find ./*.sh -type f -exec ${RUN_SHELLCHECK}"
fi
