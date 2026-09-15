#!/bin/bash

echo 'HUMAN USERS'

awk -F: '$3 >= 1000 {print $1}' /etc/passwd

echo 'USERS WITH LOGIN SHELL'

awk -F: '$7 ~ /bash$/ {print $1}' /etc/passwd

echo 'uid 0 acc'
root=$(awk -F: '$3 == 0 {print $1}' /etc/passwd)
rootuid=$(awk -F: '$3 == 0 {print $1}' /etc/passwd | wc -l)

if [[ $rootuid -ge 2 ]]; then
echo 'WARNING'
else
echo 'STATUS OK'
fi

users=$(cat /etc/passwd | awk -F: '$3 >= 1000 {print $1}')
echo 'LOCKED human ACCOUNTS'

for user in $users; do
    status=$(passwd -S "$user" | awk '{print $2}')

    if [[ "$status" == "L" ]]; then
        echo "$user"
    fi
done
