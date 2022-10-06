#!/bin/bash

# shellcheck disable=SC1091

########################################################################################################################
# Consul is a datacenter runtime that provides service discovery, configuration, and orchestration.
# Consul agents exchange messages on the 'main-subnet' network.
#
#  8500: handles HTTP API requests from clients
#  8300: handles RPC requests from CLI
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

REMOTE_DIR='SEDremote_dirSED'
# shellcheck disable=SC2034
LIBRARY_DIR='SEDlibrary_dirSED'	
INSTANCE_KEY='SEDinstance_keySED'						
ADMIN_EIP='SEDadmin_eipSED'									

source "${LIBRARY_DIR}"/general_utils.sh
source "${LIBRARY_DIR}"/service_consts_utils.sh
source "${LIBRARY_DIR}"/datacenter_consts_utils.sh
source "${LIBRARY_DIR}"/secretsmanager.sh
source "${LIBRARY_DIR}"/consul.sh

yum update -y && yum install -y jq

get_application "${INSTANCE_KEY}" 'consul' 'Mode'
consul_mode="${__RESULT}"

####
echo "Installing Consul in ${consul_mode} mode ..."
####

yum install -y yum-utils 

get_application "${INSTANCE_KEY}" 'consul' 'RepoUrl'
repo_url="${__RESULT}"
yum-config-manager --add-repo "${repo_url}" 
yum -y install consul 

get_datacenter 'Region'
region="${__RESULT}"
get_application "${INSTANCE_KEY}" 'consul' 'SecretName'
secret_nm="${__RESULT}"
sm_check_secret_exists "${secret_nm}" "${region}"
secret_exists="${__RESULT}"

if [[ 'server' == "${consul_mode}" ]]
then
   echo 'Server mode.' 
   
   if [[ 'false' == "${secret_exists}" ]]
   then     
      echo 'Generating Consul secret ...'

      ## Generate and save the secret in AWS secret manager.
      secret="$(consul keygen)"
      sm_create_secret "${secret_nm}" "${region}" 'consul' "${secret}" 

      echo 'Consul secret generated.'
   else
      echo 'WARN: Consul secret already generated.'
   fi
else
   echo 'Client mode.'  
      
   if [[ 'false' == "${secret_exists}" ]]
   then   
      echo 'ERROR: Consul secret not found.'

      exit 1
   else
      echo 'Consul secret found.'
   fi
fi

cd "${REMOTE_DIR}"

#
# Configuration consul.json
#

## Retrieve the secret from AWS secret manager.
sm_get_secret "${secret_nm}" "${region}"
secret="${__RESULT}"
jq --arg secret "${secret}" '.encrypt = $secret' consul.json > /etc/consul.d/consul.json

#
# SystemD consul.service
#

sed -e "s/SEDconsul_config_dirSED/$(escape '/etc/consul.d')/g" \
      systemd.service > /etc/systemd/system/consul.service
 
restart_consul_service
verify_consul_and_wait
is_ready="${__RESULT}"

if [[ 'true' == "${is_ready}" ]]
then
   echo 'Consul successfully installed.'
else
   echo 'ERROR: installing Consul.'
   
   exit 1
fi

get_instance "${INSTANCE_KEY}" 'PrivateIP'
private_ip="${__RESULT}"
get_application_port "${INSTANCE_KEY}" 'consul' 'HttpPort'
http_port="${__RESULT}"
get_application_port "${INSTANCE_KEY}" 'consul' 'DnsPort'
dns_port="${__RESULT}"
node_name="$(consul members |awk -v address="${private_ip}" '$2 ~ address {print $1}')"

yum remove -y jq

echo
echo "http://${ADMIN_EIP}:${http_port}/ui"
echo "dig @${ADMIN_EIP} -p ${dns_port} ${node_name}.node.consul"
echo

