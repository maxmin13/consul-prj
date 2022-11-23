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
# shellcheck disable=SC2034
CONSTANTS_DIR='SEDconstants_dirSED'
INSTANCE_KEY='SEDinstance_keySED'
NGINX_KEY='SEDnginx_keySED'
CONSUL_KEY='SEDconsul_keySED'
DNSMASQ_KEY='SEDdnsmasq_keySED'
REGISTRATOR_KEY='SEDregistrator_keySED'
DUMMY_KEY='SEDdummy_keySED'
ADMIN_INSTANCE_KEY='SEDadmin_instance_keySED'						
ADMIN_EIP='SEDadmin_eipSED'									

source "${LIBRARY_DIR}"/general_utils.sh
source "${LIBRARY_DIR}"/network.sh
source "${LIBRARY_DIR}"/service_consts_utils.sh
source "${LIBRARY_DIR}"/datacenter_consts_utils.sh
source "${LIBRARY_DIR}"/secretsmanager_auth.sh
source "${LIBRARY_DIR}"/consul.sh
source "${LIBRARY_DIR}"/dockerlib.sh

yum update -y && yum install -y yum-utils

# temporarily set the instance DNS to 10.0.0.2
get_datacenter 'DnsAddress'
datacenter_dns_addr="${__RESULT}"

sed -i -e "s/127.0.0.1/${datacenter_dns_addr}/g" /etc/resolv.conf
dig google.com

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
       
# load the dummy module and create a dummy0 interface.
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
 
#
# Environment variables
#

get_datacenter_application_client_interface "${INSTANCE_KEY}" "${CONSUL_KEY}" 'Ip'
consul_client_interface_addr="${__RESULT}"    
get_datacenter_application_port "${INSTANCE_KEY}" "${CONSUL_KEY}" 'HttpPort'
http_port="${__RESULT}"
get_datacenter_application_port "${INSTANCE_KEY}" "${CONSUL_KEY}" 'RpcPort'
rpc_port="${__RESULT}"

if [[ ! -v CONSUL_HTTP_ADDR && ! -v CONSUL_RPC_ADDR ]]
then
   # available from next login.
   echo "CONSUL_HTTP_ADDR=${consul_client_interface_addr}:${http_port}" >> /etc/environment
   echo "CONSUL_RPC_ADDR=${consul_client_interface_addr}:${rpc_port}" >> /etc/environment
   
   # make them available in current session without logout/login.
   export CONSUL_HTTP_ADDR="${consul_client_interface_addr}":"${http_port}"
   export CONSUL_RPC_ADDR="${consul_client_interface_addr}":"${rpc_port}"
   
   echo "Environment variables updated."
else
   echo "WARN: environment variable already updated."
fi 
 
##
## dnsmasq
##

rm -rf /etc/dnsmasq.d && mkdir /etc/dnsmasq.d
yum install -y dnsmasq
systemctl enable dnsmasq

get_datacenter_application_port "${INSTANCE_KEY}" "${DNSMASQ_KEY}" 'ConsulDnsPort'
consul_dns_port="${__RESULT}"
get_datacenter_application_consul_interface "${INSTANCE_KEY}" "${DNSMASQ_KEY}" 'Ip'
consul_interface_addr="${__RESULT}"

sed -e "s/SEDconsul_dns_addrSED/${consul_interface_addr}/g" \
    -e "s/SEDconsul_dns_portSED/${consul_dns_port}/g" \
    -e "s/SEDdefaul_dns_addrSED/${datacenter_dns_addr}/g" \
    -e "s/SEDdummy_addrSED/${dummy_addr}/g" \
        dnsmasq.conf > /etc/dnsmasq.d/dnsmasq.conf
       
echo "dnsmask configured."

##
## nginx reverse proxy.
##

if [[ 'server' == "${consul_mode}" ]]
then
   amazon-linux-extras enable nginx1
   yum clean metadata
   yum -y install nginx
   systemctl enable nginx 
   mkdir -p /etc/nginx/default.d

   # expose the consul ui through nginx reverse proxy, since Consul ui is not accessible externally
   # being 169.254.1.1 not rootable.
   
   get_datacenter_application_consul_interface "${INSTANCE_KEY}" "${NGINX_KEY}" 'Ip'
   consul_addr="${__RESULT}"
   get_datacenter_application_port "${INSTANCE_KEY}" "${NGINX_KEY}" 'ConsulHttpPort'
   consul_http_port="${__RESULT}"
   get_datacenter_application_port "${INSTANCE_KEY}" "${NGINX_KEY}" 'ConsulVaultPort'
   consul_vault_port="${__RESULT}"

   sed -e "s/SEDconsul_addrSED/${consul_addr}/g" \
       -e "s/SEDconsul_http_portSED/${consul_http_port}/g" \
       -e "s/SEDconsul_vault_portSED/${consul_vault_port}/g" \
           nginx-reverse-proxy.conf > /etc/nginx/default.d/nginx-reverse-proxy.conf
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
fi

docker_run_registrator "${registrator_nm}"

##
## DNS server
##

# set dnsmasq as the instance's DNS server (in resolv.config point to dnsmask at 127.0.0.1)
rm -f /etc/dhcp/dhclient.conf
sed -e "s/SEDdns_addrSED/127.0.0.1/g" \
        dhclient.conf > /etc/dhcp/dhclient.conf

echo 'dnsmasq configured as instance DNS server.'  

get_datacenter_application_port "${ADMIN_INSTANCE_KEY}" "${NGINX_KEY}" 'ProxyPort'
nginx_proxy_port="${__RESULT}"
get_datacenter_application_url "${ADMIN_INSTANCE_KEY}" "${CONSUL_KEY}" "${ADMIN_EIP}" "${nginx_proxy_port}"
application_url="${__RESULT}"  

echo "${application_url}" 
echo 'Reboot the instance.'
echo

exit 194

