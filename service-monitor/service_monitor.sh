#!/bin/bash

if (( $# != 1 )) || [[ -z "$1" || "$1" == -* || "$1" == *[\*\?\[\]]* ]]; then
    echo "ERROR: one literal service name required" >&2
    echo "Usage: $0 <service>" >&2
    exit 2
fi

if ! command -v systemctl >/dev/null 2>&1; then
    echo "ERROR: required command not found: systemctl" >&2
    exit 3
fi

service="$1"
if ! loadstate=$(systemctl show --property=LoadState --value -- "$service"); then
    echo "ERROR: could not query load state for $service" >&2
    exit 3
fi

case "$loadstate" in
    not-found)
        printf 'service monitor\nservice: %s\nstatus: NOT FOUND\n' "$service"
        exit 2
        ;;
    loaded|masked) ;;
    *)
        echo "ERROR: unexpected load state for $service: $loadstate" >&2
        exit 3
        ;;
esac

if systemctl is-active --quiet -- "$service"; then
    status=0
else
    status=$?
fi

case "$status" in
    0)
        printf 'service monitor\nservice: %s\nstatus: ACTIVE\n' "$service"
        exit 0
        ;;
    3)
        printf 'service monitor\nservice: %s\nstatus: INACTIVE\n' "$service"
        exit 1
        ;;
    *)
        echo "ERROR: could not query activity for $service (systemctl exit $status)" >&2
        exit 3
        ;;
esac
