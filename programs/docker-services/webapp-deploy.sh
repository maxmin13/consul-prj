#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Deploys a webapp in the container's volume.
############################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

REMOTE_DIR='SEDremote_dirSED'
LIBRARY_DIR='SEDlibrary_dirSED'
WEBAPP_ARCHIVE_NM='SEDwebapp_archiveSED'
SERVICE_KEY='SEDservice_keySED'
APPLICATION_ADDRESS='SEDapplication_addressSED'

source "${LIBRARY_DIR}"/service_consts_utils.sh
source "${LIBRARY_DIR}"/datacenter_consts_utils.sh

yum update -y

####
echo 'Deploying webapp ...'
####

get_service_application "${SERVICE_KEY}" 'HostVolume'
volume_dir="${__RESULT}"
get_service_application "${SERVICE_KEY}" 'DeployDir'
deploy_dir="${__RESULT}"
get_service_application "${SERVICE_KEY}" 'HostPort'
application_port="${__RESULT}"

rm -rf "${deploy_dir:?}"
mkdir -p "${volume_dir}"
unzip -o "${REMOTE_DIR}"/"${WEBAPP_ARCHIVE_NM}" -d "${deploy_dir}"
find "${volume_dir}" -type d -exec chmod 755 {} + 
find "${volume_dir}" -type f -exec chmod 744 {} +

get_service_webapp_url "${SERVICE_KEY}" "${APPLICATION_ADDRESS}" "${application_port}"
webapp_url="${__RESULT}"

echo 'webapp deployed.'
echo 'Reboot the (Docker) service.'
echo "${webapp_url}"
echo


