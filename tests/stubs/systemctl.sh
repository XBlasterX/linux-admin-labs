#!/bin/bash
# This stub never delegates to the host systemctl.
printf '%s\n' "$*" >> "$STUB_TRACE"

case "$1" in
    show)
        [[ $# == 5 && "$2" == --property=LoadState && "$3" == --value &&
            "$4" == -- && "$5" == "$EXPECTED_UNIT" ]] || exit 99
        case "$STUB_CASE" in
            show-failure) echo 'stub: cannot connect to system bus' >&2; exit 1 ;;
            not-found) echo not-found ;;
            empty-state) : ;;
            bad-state) echo error ;;
            masked) echo masked ;;
            *) echo loaded ;;
        esac
        ;;
    is-active)
        [[ $# == 4 && "$2" == --quiet && "$3" == -- &&
            "$4" == "$EXPECTED_UNIT" ]] || exit 99
        case "$STUB_CASE" in
            active) exit 0 ;;
            inactive|masked) exit 3 ;;
            unknown) exit 4 ;;
            *) echo 'stub: cannot query activity' >&2; exit 1 ;;
        esac
        ;;
    *) exit 99 ;;
esac
