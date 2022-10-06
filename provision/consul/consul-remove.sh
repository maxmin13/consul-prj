#!/bin/bash

# shellcheck disable=SC1091

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# shellcheck disable=SC2034
LIBRARY_DIR='SEDlibrary_dirSED'	
INSTANCE_KEY='SEDinstance_keySED'

source "${LIBRARY_DIR}"/general_utils.sh
source "${LIBRARY_DIR}"/service_consts_utils.sh
source "${LIBRARY_DIR}"/datacenter_consts_utils.sh
source "${LIBRARY_DIR}"/secretsmanager.sh
source "${LIBRARY_DIR}"/consul.sh

yum install -y jq

####
echo 'Removing Consul ...'
####

get_datacenter 'Region'
region="${__RESULT}"
get_application "${INSTANCE_KEY}" 'consul' 'SecretName'
secret_nm="${__RESULT}"
sm_check_secret_exists "${secret_nm}" "${region}"
secret_exists="${__RESULT}"
get_application "${INSTANCE_KEY}" 'consul' 'Mode'
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

yum -y remove consul jq 
rm -f /etc/systemd/system/consul.service
rm -rf /etc/consul.d

systemctl daemon-reload 
yum remove -y jq

echo 'Consul removed.'
echo

