#!/bin/bash

shopt -s expand_aliases
source ~/.bashrc

disk_usage=$(disk | awk 'NR == '2' {print $5}' | tr -d '%')
service=$1

uid_root=$(user | awk -F: '{print $3'} | grep "^0$" | wc -l)

logs=$(journalctl -u sshd --no-pager | grep "session opened" | wc -l)

systemctl list-unit-files "${1}.service" &> /dev/null
is_exist=$?
systemctl is-active "${1}" &> /dev/null
is_active=$?

if [[ "$disk_usage" -lt 80 ]] && [[ "$is_exist" -eq 0 ]] && [[ "$is_active" -eq 0 ]] && [[ "$uid_root" -eq 1 ]]; then
echo 'SSHD auth succed:' "$logs"
echo 'disk: OK'
echo 'service'  "$1" 'ok'
echo 'UID 0 accounts ok'
echo 'overall status: ok'
exit 0

else
echo 'WARNING'
exit 1
fi
