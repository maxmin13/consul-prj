#!/bin/bash

shared_log_file=/var/log/secured_linux_checks.log

{
echo 'Script to check some Linux security issues' 
echo '#' 
echo '# * root account' 
echo '# * running net-listeners' 
echo '# * unwanted SUID and SGUI binaries'
echo '# * world-writable files' 
echo '# * noowner files'
echo '#' 

# the third column of the file /etc/passwd is the user id, 0 is reserved for the root account

echo 'root account:'
echo 'There should be only one root account.'
awk -F: '($3==0){print}' /etc/passwd 
echo

echo 'Running net-listeners:'
netstat -tulpn 
echo

echo 'Unwanted SUID and SGID Binaries:'
echo 'All SUID/SGID bits enabled file can be misused when the SUID/SGID executable has a security problem or bug.'
echo 'All local or remote user can use such file. It is a good idea to find all such files and disable them.'
echo

echo 'All user id files:'
find / -perm /4000 
echo

echo 'All group id files:'
find / -perm /2000 
echo

echo 'World-writable files:'
echo 'Anyone can modify world-writable file resulting into a security issue.'
find / -xdev -type d \( -perm -0002 -a ! -perm -1000 \) 
echo

echo 'Noowned files:'
echo 'Files not owned by any user or group can pose a security problem.'
find / -xdev \( -nouser -o -nogroup \) 
echo

} >> "${shared_log_file}" 2>&1

echo "Linux security issues checked, see: ${shared_log_file}."
