#!/bin/bash

# shellcheck disable=SC1091

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR='SEDscripts_dirSED'
DTC_REGION='SEDdtc_regionSED'
CONSUL_SERVICE_FILE_NM='SEDconsul_service_file_nmSED'
CONSUL_SECRET_NM='SEDconsul_secret_nmSED'
CONSUL_IS_SERVER='SEDconsul_is_serverSED'

source "${SCRIPTS_DIR}"/general_utils.sh
source "${SCRIPTS_DIR}"/secretsmanager.sh

####
echo 'Removing Consul ...'
####

set +e
sm_check_secret_exists "${CONSUL_SECRET_NM}" "${DTC_REGION}"
set -e

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
rm -rf /etc/consul.d/scripts
rm -rf /var/consul
rm -rf /opt/consul
systemctl daemon-reload 

echo 'Consul removed.'
echo

