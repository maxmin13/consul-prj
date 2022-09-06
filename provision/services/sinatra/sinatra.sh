#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Installs a Sinatra server in a Docker container.
# Mounts a sample webapp in the container.
############################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR='SEDscripts_dirSED'
SINATRA_DOCKER_REPOSITORY_URI='SEDsinatra_docker_repository_uriSED'
SINATRA_DOCKER_IMG_NM='SEDsinatra_docker_img_nmSED'
SINATRA_DOCKER_IMG_TAG='SEDsinatra_docker_img_tagSED'
SINATRA_DOCKER_CONTAINER_NM='SEDsinatra_docker_container_nmSED'
SINATRA_DOCKER_CONTAINER_VOLUME_DIR='SEDsinatra_docker_container_volume_dirSED'
SINATRA_DOCKER_HOST_VOLUME_DIR='SEDsinatra_docker_host_volume_dirSED'
SINATRA_DOCKER_CONTAINER_NETWORK_NM='SEDsinatra_docker_container_network_nmSED'
SINATRA_HTTP_ADDRESS='SEDsinatra_http_addressSED'
SINATRA_HTTP_PORT='SEDsinatra_http_portSED'  
SINATRA_ARCHIVE='SEDsinatra_archiveSED'

source "${SCRIPTS_DIR}"/app_consts.sh
source "${SCRIPTS_DIR}"/general_utils.sh
source "${SCRIPTS_DIR}"/dockerlib.sh
source "${SCRIPTS_DIR}"/ecr.sh

yum update -y 

####
echo 'Running Sinatra ...'
####

#
# ECR repository
#

set +e
ecr_check_repository_exists "${SINATRA_DOCKER_IMG_NM}"
set -e

repository_exists="${__RESULT}"

if [[ 'false' == "${repository_exists}" ]]
then
   echo 'Repository not found.'
   exit  1
fi

echo 'Loggin into ECR registry ...'

ecr_get_registry_uri
ecr_registry_uri="${__RESULT}"
ecr_get_login_pwd
ecr_login_pwd="${__RESULT}"
docker_login_ecr_registry "${ecr_registry_uri}" "${ecr_login_pwd}" 

echo 'Logged into ECR registry.'

docker_check_container_exists "${SINATRA_DOCKER_CONTAINER_NM}"
container_exists="${__RESULT}"

if [[ 'true' == "${container_exists}" ]]
then
  docker_stop_container "${SINATRA_DOCKER_CONTAINER_NM}" 
  docker_delete_container "${SINATRA_DOCKER_CONTAINER_NM}" 
  
  echo 'Container removed.'
fi

# Create a volume directory to mount the Sinatra sources into the container.
mkdir -p "${SINATRA_DOCKER_HOST_VOLUME_DIR}" 
chmod 700 "${SINATRA_DOCKER_HOST_VOLUME_DIR}" 

echo 'Deploying the welcome website ...'                             

unzip -o "${SCRIPTS_DIR}"/"${SINATRA_ARCHIVE}" -d "${SINATRA_DOCKER_HOST_VOLUME_DIR}" 
find "${SINATRA_DOCKER_HOST_VOLUME_DIR}" -type d -exec chmod 755 {} + 
find "${SINATRA_DOCKER_HOST_VOLUME_DIR}" -type f -exec chmod 744 {} +

echo 'Welcome website deployed.'
echo 'Running container ...'
  
docker_run_sinatra_container "${SINATRA_DOCKER_CONTAINER_NM}" \
                             "${SINATRA_DOCKER_REPOSITORY_URI}" \
                             "${SINATRA_DOCKER_IMG_TAG}" \
                             "${SINATRA_HTTP_PORT}" \
                             "${SINATRA_DOCKER_HOST_VOLUME_DIR}" \
                             "${SINATRA_DOCKER_CONTAINER_VOLUME_DIR}" \
                             "${SINATRA_DOCKER_CONTAINER_NETWORK_NM}"
                             
docker_logout_ecr_registry "${ecr_registry_uri}" 
   
echo 'Logged out of ECR registry.'                                                                                                
echo
echo "http://${SINATRA_HTTP_ADDRESS}:${SINATRA_HTTP_PORT}/info"
echo
