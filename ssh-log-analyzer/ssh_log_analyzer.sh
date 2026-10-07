#!/bin/bash

# Count only the supported journalctl -o cat message pattern, not all failures.
set -o pipefail
export LC_ALL=C

if (( $# > 1 )); then
    echo "Usage: $0 [message-file]" >&2
    exit 2
fi

for dependency in awk sort; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        echo "ERROR: required command not found: $dependency" >&2
        exit 3
    fi
done

summarize() {
    awk '
        $1 == "Connection" && $2 == "closed" && $3 == "by" &&
        $4 == "authenticating" && $5 == "user" && NF >= 9 &&
        $8 == "port" && $9 ~ /^[0-9]+$/ { counts[$7]++ }
        END { for (ip in counts) printf "%d %s\n", counts[ip], ip }
    ' | sort -k1,1nr -k2,2
}

if (( $# == 1 )); then
    if [[ ! -f "$1" || ! -r "$1" ]]; then
        echo "ERROR: expected a readable regular message file: $1" >&2
        exit 2
    fi
    if ! report=$(summarize < "$1"); then
        echo "ERROR: could not analyze message file" >&2
        exit 3
    fi
else
    if ! command -v journalctl >/dev/null 2>&1; then
        echo "ERROR: required command not found: journalctl" >&2
        exit 3
    fi
    if ! logs=$(journalctl -u "${SSH_UNIT:-sshd}" --no-pager -o cat); then
        echo "ERROR: could not read SSH journal" >&2
        exit 3
    fi
    if ! report=$(summarize <<< "$logs"); then
        echo "ERROR: could not analyze SSH journal" >&2
        exit 3
    fi
fi

total=0
while read -r count ip; do
    if [[ -n "$count" ]]; then
        total=$((total + count))
    fi
done <<< "$report"

if (( total > 0 )); then
    printf 'TOP SOURCE IP\n%s\n' "$report"
fi
printf 'Matched SSH log messages: %d\n' "$total"
