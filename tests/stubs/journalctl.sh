#!/bin/bash
# Unexpected access (including access during a file test) is a test failure.
printf '%s\n' "$*" >> "$STUB_TRACE"
[[ $# == 5 && "$1" == -u && "$2" == "$EXPECTED_UNIT" &&
    "$3" == --no-pager && "$4" == -o && "$5" == cat ]] || exit 99

case "$STUB_CASE" in
    journal-ok) cat "$FIXTURE" ;;
    journal-empty) exit 0 ;;
    journal-failure)
        cat "$FIXTURE" # Even partial output must not become a success report.
        echo 'stub: journal access denied' >&2
        exit 1
        ;;
    *) exit 99 ;;
esac
