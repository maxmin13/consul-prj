#!/bin/bash

# shellcheck disable=SC1091

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

remote_dir='SEDscripts_dirSED'
DTC_REGION='SEDdtc_regionSED'
CONSUL_SERVICE_FILE_NM='SEDconsul_service_file_nmSED'
CONSUL_SECRET_NM='SEDconsul_secret_nmSED'
CONSUL_IS_SERVER='SEDconsul_is_serverSED'
CONSUL_CONFIG_DIR="SEDconsul_config_dirSED"

source "${remote_dir}"/general_utils.sh
source "${remote_dir}"/secretsmanager.sh

####
echo 'Removing Consul ...'
####

sm_check_secret_exists "${CONSUL_SECRET_NM}" "${DTC_REGION}"
secret_exists="${__RESULT}"

if [[ 'true' == "${CONSUL_IS_SERVER}" ]]
then
   echo 'Server mode.' 
   
   if [[ 'false' == "${secret_exists}" ]]
   then     
      echo 'WARN: Consul key not found.'
   else
      echo 'Removing Consul key ...'
   
      sm_delete_secret "${CONSUL_SECRET_NM}" "${DTC_REGION}"
      
      echo 'Consul key removed.'
   fi
else
   echo 'Client mode.'  
fi

yum -y remove consul jq 
rm -f /etc/systemd/system/"${CONSUL_SERVICE_FILE_NM}"
rm -rf "${CONSUL_CONFIG_DIR}"
systemctl daemon-reload 

echo 'Consul removed.'
echo

