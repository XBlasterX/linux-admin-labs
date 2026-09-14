#!/bin/bash

if [[ -z "$1" ]]; then
    echo "ERROR: service name required"
    echo "Usage: ./service_monitor.sh <service>"
    exit 2
fi

service="$1"

loadstate=$(systemctl show "$service" --property=LoadState --value)

if [[ "$loadstate" == "not-found" ]]; then
    echo "service monitor"
    echo "service: $service"
    echo "status: NOT FOUND"
    exit 2
fi

if systemctl is-active --quiet "$service"; then
    echo "service monitor"
    echo "service: $service"
    echo "status: ACTIVE"
    exit 0
else
    echo "service monitor"
    echo "service: $service"
    echo "status: INACTIVE"
    exit 1
fi
