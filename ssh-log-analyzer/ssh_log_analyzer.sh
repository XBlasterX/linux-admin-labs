#!/bin/bash

failedattempts=$(journalctl -u sshd --no-pager -o cat | grep "Connection closed by authenticating user " | sort | sort -nr | wc -l)
ipfailed=$(journalctl -u sshd --no-pager -o cat \
| grep "Connection closed by authenticating user" \
| awk '{print $7}' \
| sort \
| uniq -c \
| sort -nr)

if [ $failedattempts -gt 0 ]; then
echo 'TOP SOURCE IP'
echo "$ipfailed"
echo 'failed authentication attempts:' "$failedattempts"
elif [ $failedattempts -eq 0 ]; then
echo 'failed login attempts: 0'
echo 'No failed SSH logins detected.'
fi
