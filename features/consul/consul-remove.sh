#!/bin/bash

##########################################################################################################
# The script removes Consul from the instance and restores the original DNS configuration.
##########################################################################################################

# shellcheck disable=SC1091

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# shellcheck disable=SC2034
LIBRARY_DIR='SEDlibrary_dirSED'	
# shellcheck disable=SC2034
CONSTANTS_DIR='SEDconstants_dirSED'
REMOTE_DIR='SEDremote_dirSED'	
INSTANCE_KEY='SEDinstance_keySED'
CONSUL_KEY='SEDconsul_keySED'
DUMMY_KEY='SEDdummy_keySED'
REGISTRATOR_KEY='SEDregistrator_keySED'

source "${LIBRARY_DIR}"/general_utils.sh
source "${LIBRARY_DIR}"/network.sh
source "${LIBRARY_DIR}"/service_consts_utils.sh
source "${LIBRARY_DIR}"/datacenter_consts_utils.sh
source "${LIBRARY_DIR}"/secretsmanager.sh
source "${LIBRARY_DIR}"/consul.sh
source "${LIBRARY_DIR}"/dockerlib.sh

cd "${REMOTE_DIR}"

# temporarily set the instance DNS to 10.0.0.2
get_datacenter 'DnsAddress'
datacenter_dns_addr="${__RESULT}"

sed -i -e "s/127.0.0.1/${datacenter_dns_addr}/g" /etc/resolv.conf
dig google.com

####
echo 'Removing Consul ...'
####

##
## nginx
##

yum remove -y nginx
rm -rf /etc/nginx/default.d

echo 'nginx server successfull removed.'

##
## Consul
##

get_datacenter 'Region'
region="${__RESULT}"
get_datacenter_application "${INSTANCE_KEY}" "${CONSUL_KEY}" 'SecretName'
secret_nm="${__RESULT}"
sm_check_secret_exists "${secret_nm}" "${region}"
secret_exists="${__RESULT}"
get_datacenter_application "${INSTANCE_KEY}" "${CONSUL_KEY}" 'Mode'
consul_mode="${__RESULT}"

if [[ 'server' == "${consul_mode}" ]]
then
   echo 'Server mode.' 
   
   if [[ 'false' == "${secret_exists}" ]]
   then     
      echo 'WARN: Consul key not found.'
   else
      echo 'Removing Consul key ...'
   
      sm_delete_secret "${secret_nm}" "${region}"
      
      echo 'Consul key removed.'
   fi
else
   echo 'Client mode.'  
fi

yum -y remove consul
rm -f /etc/systemd/system/consul.service
rm -rf /etc/consul.d

echo 'Consul removed.'

#
# Environment variables
#

grep -vwE "CONSUL_HTTP_ADDR" /etc/environment > tmpfile && mv tmpfile /etc/environment
grep -vwE "CONSUL_RPC_ADDR" /etc/environment > tmpfile && mv tmpfile /etc/environment

echo "Consul environment variables removed."

##
## dummy interface. 
##

rm -f /etc/sysconfig/network-scripts/ifcfg-dummy

get_datacenter_network "${DUMMY_KEY}" 'Name' 
dummy_nm="${__RESULT}"
ip_check_protocol_address_exists "${dummy_nm}"
dummy_nm_exists="${__RESULT}"

if [[ 'true' == "${dummy_nm_exists}" ]]
then
   ip_delete_network_interface "${dummy_nm}" 
   
   echo 'Dummy interface deleted.'
else
   echo 'WARN: dummy interface not found.'
fi

##
## Registrator
##

get_datacenter_application "${INSTANCE_KEY}" "${REGISTRATOR_KEY}" 'Name'
registrator_nm="${__RESULT}"
docker_check_container_exists "${registrator_nm}"
container_exists="${__RESULT}"

if [[ 'true' == "${container_exists}" ]]
then
   docker_stop_container "${registrator_nm}"
   docker_delete_container "${registrator_nm}"
   
   echo 'Registrator container removed.'
else
   echo 'WARN: Registrator container already removed.'
fi

##
## dnsmasq
##

yum remove -y dnsmasq
rm -rf /etc/dnsmasq.d 

echo 'dnsmasq successfull removed.'

##
## DNS server
##

get_datacenter 'DnsAddress'
datacenter_dns_addr="${__RESULT}"

# set the AWS DNS service as the instance's DNS.
rm -f /etc/dhcp/dhclient.conf
sed -e "s/SEDdns_addrSED/${datacenter_dns_addr}/g" \
        dhclient.conf > /etc/dhcp/dhclient.conf

echo 'Reboot the instance.'
echo

exit 194

