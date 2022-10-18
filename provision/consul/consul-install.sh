#!/bin/bash

# shellcheck disable=SC1091

########################################################################################################################
#
# Consul is a datacenter runtime that provides service discovery, configuration, and orchestration.
# Consul agents exchange cluster messages on the host network.
# Consul binds its RPC CLI, HTTP, DNS services to a local dummy interface.
#
# Install dnsmasq and bind it to both loopback and dummy interfaces; 
# configure /etc/resolv.conf on both the host and our containers to dispatch DNS queries to it;
# dnsmask passes queries ending in .consul to the Consul agent; 
#
# Consul ui is exposed through nginx reverse proxy.
#
########################################################################################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

REMOTE_DIR='SEDremote_dirSED'
# shellcheck disable=SC2034
LIBRARY_DIR='SEDlibrary_dirSED'	
INSTANCE_KEY='SEDinstance_keySED'
NGINX_KEY='SEDnginx_keySED'
DUMMY_KEY='SEDdummy_keySED'
ADMIN_KEY='SEDadmin_keySED'						
ADMIN_EIP='SEDadmin_eipSED'									

source "${LIBRARY_DIR}"/general_utils.sh
source "${LIBRARY_DIR}"/network.sh
source "${LIBRARY_DIR}"/service_consts_utils.sh
source "${LIBRARY_DIR}"/datacenter_consts_utils.sh
source "${LIBRARY_DIR}"/secretsmanager.sh
source "${LIBRARY_DIR}"/consul.sh

yum update -y && yum install -y yum-utils jq

get_datacenter_application "${INSTANCE_KEY}" 'consul' 'Mode'
consul_mode="${__RESULT}"

####
echo "Installing Consul in ${consul_mode} mode ..."
####

yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
rm -rf /etc/consul.d && mkdir /etc/consul.d
yum -y install consul
systemctl enable consul 

cd "${REMOTE_DIR}"

#
# dummy interface. 
#

get_datacenter_network "${DUMMY_KEY}" 'Name' 
dummy_nm="${__RESULT}"
get_datacenter_network "${DUMMY_KEY}" 'Address' 
dummy_addr="${__RESULT}"
get_datacenter_network "${DUMMY_KEY}" 'Mask'
dummy_mask="${__RESULT}"

rm -f /etc/sysconfig/network-scripts/ifcfg-dummy

sed -e "s/SEDdummy_nmSED/${dummy_nm}/g" \
    -e "s/SEDdummy_addrSED/${dummy_addr}/g" \
    -e "s/SEDdummy_maskSED/${dummy_mask}/g" \
       ifcfg-dummy > /etc/sysconfig/network-scripts/ifcfg-dummy 
       
# load the dummy module and create a dummy interface.
\cp dummymodule.conf /etc/modules-load.d/

#
# Consul security key
#

get_datacenter 'Region'
region="${__RESULT}"
get_datacenter_application "${INSTANCE_KEY}" 'consul' 'SecretName'
consul_secret_nm="${__RESULT}"

sm_check_secret_exists "${consul_secret_nm}" "${region}"
consul_secret_exists="${__RESULT}"

if [[ 'server' == "${consul_mode}" ]]
then
   echo 'Server mode.' 
   
   if [[ 'false' == "${consul_secret_exists}" ]]
   then     
      echo 'Generating Consul secret ...'

      ## Generate and save the secret in AWS secret manager.
      key="$(consul keygen)"
      sm_create_secret "${consul_secret_nm}" "${region}" 'consul' "${key}" 

      echo 'Consul secret generated.'
   else
      echo 'WARN: Consul secret already generated.'
   fi
else
   echo 'Client mode.'  
      
   if [[ 'false' == "${consul_secret_exists}" ]]
   then   
      echo 'ERROR: Consul secret not found.'

      exit 1
   else
      echo 'Consul secret found.'
   fi
fi

## Retrieve the secret from AWS secret manager.
sm_get_secret "${consul_secret_nm}" "${region}"
consul_secret="${__RESULT}"

#
# Consul configuration file.
#

# Configure Consul to join the host's private network for cluster communications,
# to bind its DNS, HTTP, RPC services to the dummy network interface's IP address. 
# If it's a consul client agent, configure Consul to join the consul server agent at start-up.

get_datacenter_instance "${INSTANCE_KEY}" 'PrivateIP'
host_addr="${__RESULT}"
get_datacenter_instance_admin 'PrivateIP'
consul_start_bind_addr="${__RESULT}"
get_datacenter_application_client_interface "${INSTANCE_KEY}" 'consul' 'Ip'
consul_client_interface_addr="${__RESULT}"

sed -i \
    -e "s/SEDbind_addressSED/${host_addr}/g" \
    -e "s/SEDclient_addrSED/${consul_client_interface_addr}/g" \
    -e "s/SEDbootstrap_expectSED/1/g" \
    -e "s/SEDstart_join_bind_addressSED/${consul_start_bind_addr}/g" \
        consul-config.json 
       
jq --arg secret "${consul_secret}" '.encrypt = $secret' consul-config.json > /etc/consul.d/consul-config.json

echo "Consul configured with bind address ${host_addr} and client address ${consul_client_interface_addr}."

#
# Consul systemd service.
#

sed "s/SEDconsul_config_dirSED/$(escape '/etc/consul.d')/g" \
     consul-systemd.service > /etc/systemd/system/consul.service
 
#
# dnsmasq
#

# Configure dnsmasq to listen to the dummy IP address.

rm -rf /etc/dnsmasq.d && mkdir /etc/dnsmasq.d
yum install -y dnsmasq
systemctl enable dnsmasq

get_datacenter_application_port "${INSTANCE_KEY}" 'dnsmasq' 'DnsPort'
dnsmaq_dns_port="${__RESULT}"
get_datacenter_application_dns_interface "${INSTANCE_KEY}" 'dnsmasq' 'Ip'
dnsmasq_dns_interface_addr="${__RESULT}"

# AWS default DNS address, the IP address of the AWS DNS server is always the base of the VPC network range plus two (10.0.0.2: Reserved by AWS).
get_datacenter 'DnsAddress'
dns_addr="${__RESULT}"

sed -e "s/SEDclient_addrSED/${dnsmasq_dns_interface_addr}/g" \
    -e "s/SEDdns_portSED/${dnsmaq_dns_port}/g" \
    -e "s/SEDdns_addrSED/${dns_addr}/g" \
        dnsmasq.conf > /etc/dnsmasq.d/dnsmasq.conf
       
echo "dnsmask configured with client address ${dnsmasq_dns_interface_addr} and dns port ${dnsmaq_dns_port}."

#
# DNS server
#

# change resolv.config, point to dnsmask at 127.0.0.1
\cp dhclient.conf /etc/dhcp/

echo 'Instance DNS server configured.'      

get_datacenter_application_port "${INSTANCE_KEY}" 'consul' 'HttpPort'
consul_http_port="${__RESULT}"
get_datacenter_application_port "${INSTANCE_KEY}" 'consul' 'DnsPort'
#consul_dns_port="${__RESULT}"
#node_name="$(consul members |awk -v address="${host_addr}" '$2 ~ address {print $1}')"

#
# nginx
#

if [[ 'server' == "${consul_mode}" ]]
then
   amazon-linux-extras enable nginx1
   yum clean metadata
   yum -y install nginx
   systemctl enable nginx 

   # expose the consul ui through nginx reverse proxy, since Consul ui is not accessible externally
   # being 169.254.1.1 not rootable.

   sed -e "s/SEDclient_addrSED/${dnsmasq_dns_interface_addr}/g" \
      nginx-reverse-proxy.conf > /etc/nginx/default.d/nginx-reverse-proxy.conf
fi

get_datacenter_application_port "${ADMIN_KEY}" "${NGINX_KEY}" 'Port'
nginx_port="${__RESULT}"
get_datacenter_application_url "${ADMIN_KEY}" "${NGINX_KEY}" "${ADMIN_EIP}" "${nginx_port}"
application_url="${__RESULT}"  

yum remove -y jq
    
echo "${application_url}" 
echo 'Restart the instance.'
echo

exit 194

