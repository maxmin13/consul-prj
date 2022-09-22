#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Installs a Sinatra server in a Docker container.
# Mounts a sample webapp in the container.
# Register Sinatra with the local Consul agent.
############################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

remote_dir='SEDscripts_dirSED'
REGION='SEDregionSED'
DOCKER_REPOSITORY_URI='SEDdocker_repository_uriSED'
DOCKER_IMG_NM='SEDdocker_img_nmSED'
DOCKER_IMG_TAG='SEDdocker_img_tagSED'
DOCKER_CONTAINER_NM='SEDdocker_container_nmSED'
DOCKER_CONTAINER_VOLUME_DIR='SEDdocker_container_volume_dirSED'
DOCKER_HOST_VOLUME_DIR='SEDdocker_host_volume_dirSED'
DOCKER_CONTAINER_NETWORK_NM='SEDdocker_container_network_nmSED'
HTTP_ADDRESS='SEDhttp_addressSED'
HTTP_PORT='SEDhttp_portSED'  
ARCHIVE='SEDarchiveSED'
CONSUL_CONFIG_DIR="SEDconsul_config_dirSED"
CONSUL_SERVICE_FILE_NM='SEDconsul_service_file_nmSED'

source "${remote_dir}"/general_utils.sh
source "${remote_dir}"/dockerlib.sh
source "${remote_dir}"/ecr.sh
source "${remote_dir}"/consul.sh

yum update -y 

####
echo 'Running Sinatra ...'
####

#
# ECR repository
#

ecr_check_repository_exists "${DOCKER_IMG_NM}" "${REGION}"
repository_exists="${__RESULT}"

if [[ 'false' == "${repository_exists}" ]]
then
   echo 'Repository not found.'
   exit  1
fi

echo 'Loggin into ECR registry ...'

ecr_get_registry_uri "${REGION}"
registry_uri="${__RESULT}"
ecr_get_login_pwd "${REGION}"
login_pwd="${__RESULT}"
docker_login_ecr_registry "${registry_uri}" "${login_pwd}" 

echo 'Logged into ECR registry.'

docker_check_container_exists "${DOCKER_CONTAINER_NM}"
container_exists="${__RESULT}"

if [[ 'true' == "${container_exists}" ]]
then
  docker_stop_container "${DOCKER_CONTAINER_NM}" 
  docker_delete_container "${DOCKER_CONTAINER_NM}" 
  
  echo 'Container removed.'
fi

# Create a volume directory to mount the Sinatra sources into the container.
mkdir -p "${DOCKER_HOST_VOLUME_DIR}" 
chmod 700 "${DOCKER_HOST_VOLUME_DIR}" 

echo 'Deploying the welcome website ...'                             

unzip -o "${remote_dir}"/"${ARCHIVE}" -d "${DOCKER_HOST_VOLUME_DIR}" 
find "${DOCKER_HOST_VOLUME_DIR}" -type d -exec chmod 755 {} + 
find "${DOCKER_HOST_VOLUME_DIR}" -type f -exec chmod 744 {} +

echo 'Welcome website deployed.'
echo 'Running container ...'
  
docker_run_sinatra_container "${DOCKER_CONTAINER_NM}" \
                             "${DOCKER_REPOSITORY_URI}" \
                             "${DOCKER_IMG_TAG}" \
                             "${HTTP_PORT}" \
                             "${DOCKER_HOST_VOLUME_DIR}" \
                             "${DOCKER_CONTAINER_VOLUME_DIR}" \
                             "${DOCKER_CONTAINER_NETWORK_NM}"
                             
docker_logout_ecr_registry "${registry_uri}" 
   
echo 'Logged out of ECR registry.'     
echo 'Registering Sinatra with Consul agent ...'

cd "${remote_dir}"
cp "${CONSUL_SERVICE_FILE_NM}" "${CONSUL_CONFIG_DIR}"

restart_consul_service

echo 'Sinatra registered with Consul agent.'
                                                                                           
echo
echo "http://${HTTP_ADDRESS}:${HTTP_PORT}/info"
echo
