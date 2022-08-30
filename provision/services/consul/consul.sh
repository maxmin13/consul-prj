#!/bin/bash

# shellcheck disable=SC1091

########################################################################################################################
# Consul is a datacenter runtime that provides service discovery, configuration, and orchestration.
# By default, Consul allows connections to the following ports only from the loopback interface (127.0.0.1). 
#  8500: handles HTTP API requests from clients
#  8400: handles requests from CLI
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

SCRIPTS_DIR='SEDscripts_dirSED'
DTC_REGION='SEDdtc_regionSED'
INSTANCE_EIP_ADDRESS='SEDinstance_eip_addressSED'
INSTANCE_PRIVATE_ADDRESS='SEDinstance_private_addressSED'
CONSUL_CONFIG_FILE_NM='SEDconsul_config_file_nmSED'
CONSUL_SERVICE_FILE_NM='SEDconsul_service_file_nmSED'
CONSUL_HTTP_PORT='SEDconsul_http_portSED'
CONSUL_DNS_PORT='SEDconsul_dns_portSED'
AGENT_MODE='SEDagent_modeSED'
CONSUL_SECRET_NM='SEDconsul_secret_nmSED'

source "${SCRIPTS_DIR}"/general_utils.sh
source "${SCRIPTS_DIR}"/secretsmanager.sh

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

if [[ 'false' == "${secret_exists}" ]]
then
   if [[ 'server' == "${AGENT_MODE}" ]]
   then
      echo 'Server mode.'      
      echo 'Generating Consul key ...'
   
      ## Generate and save the secret in AWS secret manager.
      key_value="$(consul keygen)"
      sm_create_secret "${CONSUL_SECRET_NM}" "${DTC_REGION}" 'consul' "${key_value}" 
   
      echo 'Consul key generated.'
   else
      echo 'Client mode.'     
      echo 'ERROR: Consul key not found.'
      
      exit 1
   fi
fi

## Retrieve the secret from AWS secret manager.
sm_get_secret "${CONSUL_SECRET_NM}" "${DTC_REGION}"
secret="${__RESULT}"

cd "${SCRIPTS_DIR}"
jq --arg secret "${secret}" '.encrypt = $secret' "${CONSUL_CONFIG_FILE_NM}" > /etc/consul.d/"${CONSUL_CONFIG_FILE_NM}"
cp "${CONSUL_SERVICE_FILE_NM}" /etc/systemd/system/

echo 'Consul installed.'

systemctl daemon-reload
systemctl restart consul
systemctl status consul 
consul version

consul members 2>&1 > /dev/null && echo "Consul ${AGENT_MODE} successfully started." || 
{
   echo "Waiting for Consul ${AGENT_MODE} to start" 
      
   wait 60
   
   consul members && echo "Consul ${AGENT_MODE} successfully started." || 
   {
      echo "ERROR: Consul ${AGENT_MODE} not started after 1 minute."
      exit 1
   }
}

yum remove -y jq

node_name="$(consul members |awk -v address="${INSTANCE_PRIVATE_ADDRESS}" '$2 ~ address {print $1}')"

echo
if [[ 'server' == "${AGENT_MODE}" ]]
then  
   echo "http://${INSTANCE_EIP_ADDRESS}:${CONSUL_HTTP_PORT}/ui"
   echo "dig @${INSTANCE_EIP_ADDRESS} -p ${CONSUL_DNS_PORT} ${node_name}.node.consul"
   echo
fi
