#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# ****************************************************************
# Script to make Linux more secure, 
# requires yumupdate.sh.
# ****************************************************************

script_dir='SEDscript_dirSED'

cd "${script_dir}"

yum -y update 
echo 'Programs installed.'

cp yumupdate.sh /etc/cron.daily/yumupdate.sh
chmod +x /etc/cron.daily/yumupdate.sh
echo 'Daily YUM update configured.'

# New sshd config
cp sshd_config /etc/ssh/sshd_config
chown root:root /etc/ssh/sshd_config
chmod 400 /etc/ssh/sshd_config
echo 'SSH configured.'

# Turn off unwanted services
#chkconfig ip6tables off
#echo 'ip6tables off'

# Disable ipv6
echo 'install ipv6 /bin/true' > /etc/modprobe.d/disable-ipv6.conf
echo 'net.ipv6.conf.all.disable_ipv6 = 1' >> /etc/sysctl.conf

echo 'IPV6 disabled.'

# Harden kernel /etc/sysctl.conf
{
   echo 'kernel.exec-shield=1'  
   echo 'kernel.randomize_va_space=1' 
   echo 'net.ipv4.conf.all.rp_filter=1' 
   echo 'net.ipv4.conf.all.accept_source_route=0'
   echo 'net.ipv4.icmp_echo_ignore_broadcasts=1'  
   echo 'net.ipv4.icmp_ignore_bogus_error_messages=1' 
} >> /etc/sysctl.conf

echo 'Kernel hardened.'

yum remove -y expect 

echo 'Reboot the server.'

exit 194
