#!/bin/bash

# shellcheck disable=SC1091

########################################################################################################################
#
# Consul provides service-discovery capability to your network.
# It allows to publish the services running in containers into Consul’s service catalog.
#
# 1) configure Consul to bind its RPC CLI, HTTP, DNS services to a local dummy interface with IP address 169.254.1.1.
# 2) configure dnsmasq to listen to the dummy 169.254.1.1 IP address and to the loopback 127.0.0.1 IP address.
# 3) configure containers to use the dummy IP address as their DNS resolver and Consul server.
# 4) configure the instance to use the loopback IP address as its DNS resolver.
# 5) in the Admin instance, configure Consul ui to run behind an Nginx reverse proxy on port 80.
# 
# dnsmask passes queries ending in .consul to the Consul agent, while the remaining queries are passed to AWS DNS server
# at 10.0.0.2.
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
CONSUL_KEY='SEDconsul_keySED'
DNSMASQ_KEY='SEDdnsmasq_keySED'
DUMMY_KEY='SEDdummy_keySED'
ADMIN_INSTANCE_KEY='SEDadmin_instance_keySED'						
ADMIN_EIP='SEDadmin_eipSED'									

source "${LIBRARY_DIR}"/general_utils.sh
source "${LIBRARY_DIR}"/network.sh
source "${LIBRARY_DIR}"/service_consts_utils.sh
source "${LIBRARY_DIR}"/datacenter_consts_utils.sh
source "${LIBRARY_DIR}"/secretsmanager.sh
source "${LIBRARY_DIR}"/consul.sh

yum update -y && yum install -y yum-utils jq

get_datacenter_application "${INSTANCE_KEY}" "${CONSUL_KEY}" 'Mode'
consul_mode="${__RESULT}"

####
echo "Installing Consul in ${consul_mode} mode ..."
####

yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
rm -rf /etc/consul.d && mkdir /etc/consul.d
yum -y install consul
systemctl enable consul 

cd "${REMOTE_DIR}"

##
## dummy interface. 
##

# link-local IP address
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

echo 'Dummy interface created.'

#
# Consul security key
#

get_datacenter 'Region'
region="${__RESULT}"
get_datacenter_application "${INSTANCE_KEY}" "${CONSUL_KEY}" 'SecretName'
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

##
## Consul configuration file.
##

# Configure Consul to join the host's private network for cluster communications,
# to bind its DNS, HTTP, RPC services to the dummy network interface's IP address. 
# If it's a consul client agent, configure Consul to join the consul server agent at start-up.

get_datacenter_instance_admin 'PrivateIP'
admin_host_addr="${__RESULT}"
get_datacenter_application_client_interface "${INSTANCE_KEY}" "${CONSUL_KEY}" 'Ip'
consul_client_interface_addr="${__RESULT}"
get_datacenter_application_bind_interface "${INSTANCE_KEY}" "${CONSUL_KEY}" 'Ip'
consul_bind_interface_addr="${__RESULT}"

sed -i \
    -e "s/SEDbind_addressSED/${consul_bind_interface_addr}/g" \
    -e "s/SEDclient_addrSED/${consul_client_interface_addr}/g" \
    -e "s/SEDbootstrap_expectSED/1/g" \
    -e "s/SEDstart_join_bind_addressSED/${admin_host_addr}/g" \
        consul-config.json 
       
jq --arg secret "${consul_secret}" '.encrypt = $secret' consul-config.json > /etc/consul.d/consul-config.json

echo "Consul configured with bind address ${consul_bind_interface_addr} and client address ${consul_client_interface_addr}."

##
## Consul systemd service.
##

sed "s/SEDconsul_config_dirSED/$(escape '/etc/consul.d')/g" \
     consul-systemd.service > /etc/systemd/system/consul.service
 
##
## dnsmasq
##

rm -rf /etc/dnsmasq.d && mkdir /etc/dnsmasq.d
yum install -y dnsmasq
systemctl enable dnsmasq

get_datacenter_application_port "${INSTANCE_KEY}" "${DNSMASQ_KEY}" 'ConsulDnsPort'
dnsmaq_consul_dns_port="${__RESULT}"
get_datacenter_application_consul_interface "${INSTANCE_KEY}" "${DNSMASQ_KEY}" 'Ip'
dnsmasq_consul_interface_addr="${__RESULT}"

# AWS default DNS address, the IP address of the AWS DNS server is always the base of the VPC network range plus two (10.0.0.2: Reserved by AWS).
get_datacenter 'DnsAddress'
datacenter_dns_addr="${__RESULT}"

sed -e "s/SEDconsul_dns_addrSED/${dnsmasq_consul_interface_addr}/g" \
    -e "s/SEDconsul_dns_portSED/${dnsmaq_consul_dns_port}/g" \
    -e "s/SEDdefaul_dns_addrSED/${datacenter_dns_addr}/g" \
    -e "s/SEDdummy_addrSED/${dummy_addr}/g" \
        dnsmasq.conf > /etc/dnsmasq.d/dnsmasq.conf
       
echo "dnsmask configured."

##
## DNS server
##

# set dnsmasq as the instance's DNS server (in resolv.config point to dnsmask at 127.0.0.1)
rm -f /etc/dhcp/dhclient.conf
sed -e "s/SEDdns_addrSED/127.0.0.1/g" \
        dhclient.conf > /etc/dhcp/dhclient.conf

echo 'dnsmasq configured as the instance''s DNS server.'      

##
## nginx reverse proxy.
##

if [[ 'server' == "${consul_mode}" ]]
then
   amazon-linux-extras enable nginx1
   yum clean metadata
   yum -y install nginx
   systemctl enable nginx 

   # expose the consul ui through nginx reverse proxy, since Consul ui is not accessible externally
   # being 169.254.1.1 not rootable.
   
   get_datacenter_application_consul_interface "${INSTANCE_KEY}" "${NGINX_KEY}" 'Ip'
   nginx_consul_addr="${__RESULT}"
   get_datacenter_application_port "${INSTANCE_KEY}" "${NGINX_KEY}" 'ConsulHttpPort'
   nginx_consul_http_port="${__RESULT}"
   get_datacenter_application_port "${INSTANCE_KEY}" "${NGINX_KEY}" 'ConsulVaultPort'
   nginx_consul_vault_port="${__RESULT}"

   sed -e "s/SEDconsul_addrSED/${nginx_consul_addr}/g" \
       -e "s/SEDconsul_http_portSED/${nginx_consul_http_port}/g" \
       -e "s/SEDconsul_vault_portSED/${nginx_consul_vault_port}/g" \
           nginx-reverse-proxy.conf > /etc/nginx/default.d/nginx-reverse-proxy.conf
fi

get_datacenter_application_port "${ADMIN_INSTANCE_KEY}" "${NGINX_KEY}" 'ProxyPort'
proxy_port="${__RESULT}"
get_datacenter_application_url "${ADMIN_INSTANCE_KEY}" "${CONSUL_KEY}" "${ADMIN_EIP}" "${proxy_port}"
application_url="${__RESULT}"  

yum remove -y jq
    
echo "${application_url}" 
echo 'Restart the instance.'
echo

exit 194

