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

source "${SCRIPTS_DIR}"/general_utils.sh
source "${SCRIPTS_DIR}"/secretsmanager.sh

yum update -y && yum install -y jq 

####
echo 'Removing Consul ...'
####

yum -y remove consul jq 
rm -f /etc/systemd/system/"${CONSUL_SERVICE_FILE_NM}"
rm -rf /etc/consul.d/scripts
rm -rf /var/consul
rm -rf /opt/consul
systemctl daemon-reload 

set +e
sm_check_secret_exists "${CONSUL_SECRET_NM}" "${DTC_REGION}"
set -e

secret_exists="${__RESULT}"

if [[ 'true' == "${secret_exists}" ]]
then
   sm_delete_secret "${CONSUL_SECRET_NM}" "${DTC_REGION}"
   
   echo 'Consul key deleted.' 
fi

echo 'Consul removed.'
echo

