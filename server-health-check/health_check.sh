#!/bin/bash

#SERVER HEALTH CHECK
hostname=$(hostname)
currentuser=$(whoami)
RAM=$(free -h)
uptime=$(uptime -p)
filesystemusage=$(df -h /)
failed=$(systemctl --failed --type=service)

echo "SERVER HEALTH CHECK"
echo $hostname 
echo $currentuser
echo $uptime

echo "MEMORY"
echo "$RAM"

echo "DISK"
echo "$filesystemusage"

echo "FAILED SERVICES"
echo "$failed"
