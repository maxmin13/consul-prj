#!/bin/bash

# shellcheck disable=SC1091

########################################################################################################################
# Consul is a datacenter runtime that provides service discovery, configuration, and orchestration.
# Consul agents exchange messages on the 'main-subnet' network.
#
#  8500: handles HTTP API requests from clients
#  8300: handles requests from CLI
#  8600: answers DNS queries
#
#   dig @0.0.0.0 -p 8600 node1.node.consul
#   curl localhost:8500/v1/catalog/nodes
#
########################################################################################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

remote_script_dir='SEDscripts_dirSED'
DTC_REGION='SEDdtc_regionSED'
INSTANCE_EIP_ADDRESS='SEDinstance_eip_addressSED'
INSTANCE_PRIVATE_ADDRESS='SEDinstance_private_addressSED'
CONSUL_IS_SERVER='SEDconsul_is_serverSED'
CONSUL_CONFIG_FILE_NM='SEDconsul_config_file_nmSED'
CONSUL_SERVICE_FILE_NM='SEDconsul_service_file_nmSED'
CONSUL_HTTP_PORT='SEDconsul_http_portSED'
CONSUL_DNS_PORT='SEDconsul_dns_portSED'
CONSUL_SECRET_NM='SEDconsul_secret_nmSED'

source "${remote_script_dir}"/general_utils.sh
source "${remote_script_dir}"/secretsmanager.sh

yum update -y && yum install -y jq

####
echo 'Installing Consul ...'
####

yum install -y yum-utils 
yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo 
yum -y install consul 
mkdir -p /etc/consul.d/scripts
mkdir -p /var/consul

set +e
sm_check_secret_exists "${CONSUL_SECRET_NM}" "${DTC_REGION}"
set -e

secret_exists="${__RESULT}"

if [[ 'true' == "${CONSUL_IS_SERVER}" ]]
then
   echo 'Server mode.' 
   
   if [[ 'false' == "${secret_exists}" ]]
   then     
      echo 'Generating Consul key ...'

      ## Generate and save the secret in AWS secret manager.
      key_value="$(consul keygen)"
      sm_create_secret "${CONSUL_SECRET_NM}" "${DTC_REGION}" 'consul' "${key_value}" 

      echo 'Consul key generated.'
   else
      echo 'WARN: Consul key already generated.'
   fi
else
   echo 'Client mode.'  
      
   if [[ 'false' == "${secret_exists}" ]]
   then   
      echo 'ERROR: Consul key not found.'

      exit 1
   else
      echo 'Consul key found.'
   fi
fi

## Retrieve the secret from AWS secret manager.
sm_get_secret "${CONSUL_SECRET_NM}" "${DTC_REGION}"
secret="${__RESULT}"

cd "${remote_script_dir}"
jq --arg secret "${secret}" '.encrypt = $secret' "${CONSUL_CONFIG_FILE_NM}" > /etc/consul.d/"${CONSUL_CONFIG_FILE_NM}"
cp "${CONSUL_SERVICE_FILE_NM}" /etc/systemd/system/

echo 'Consul installed.'

systemctl daemon-reload
systemctl restart consul 
systemctl status consul 
consul version

# shellcheck disable=SC2015
consul members && echo "Consul successfully started." || 
{
   echo "Waiting for Consul to start" 
      
   wait 60
   
   # shellcheck disable=SC2015
   consul members && echo "Consul successfully started." || 
   {
      echo "ERROR: Consul not started after 1 minute."
      exit 1
   }
}

yum remove -y jq

node_name="$(consul members |awk -v address="${INSTANCE_PRIVATE_ADDRESS}" '$2 ~ address {print $1}')"

echo
echo "http://${INSTANCE_EIP_ADDRESS}:${CONSUL_HTTP_PORT}/ui"
echo "dig @${INSTANCE_EIP_ADDRESS} -p ${CONSUL_DNS_PORT} ${node_name}.node.consul"
echo

