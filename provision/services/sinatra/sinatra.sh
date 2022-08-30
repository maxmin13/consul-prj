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
SINATRA_DOCKER_CTX='SEDsinatra_docker_ctxSED'
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

yum update -y > /dev/null

####
echo 'Installing Sinatra ...'
####

docker_check_container_exists "${SINATRA_DOCKER_CONTAINER_NM}"
exists="${__RESULT}"

if [[ 'true' == "${exists}" ]]
then
  docker_stop_container "${SINATRA_DOCKER_CONTAINER_NM}" 
  docker_delete_container "${SINATRA_DOCKER_CONTAINER_NM}" 
  
  echo 'Sinatra container removed.'
fi

#
# Sinatra repository
#

set +e
ecr_check_repository_exists "${SINATRA_DOCKER_IMG_NM}"
set -e

sinatra_repository_exists="${__RESULT}"

if [[ 'false' == "${sinatra_repository_exists}" ]]
then
   ecr_create_repository "${SINATRA_DOCKER_IMG_NM}"
   
   echo 'Sinatra repository created.'
else
   echo 'Sinatra repository already created.'
fi

echo 'Loggin into ECR registry ...'

ecr_get_registry_uri
ecr_registry_uri="${__RESULT}"
ecr_get_login_pwd
ecr_login_pwd="${__RESULT}"
docker_login_ecr_registry "${ecr_registry_uri}" "${ecr_login_pwd}" 

echo 'Logged into ECR registry.'

#
# Sinatra image
#

echo 'Building Sinatra image ...'

docker_build_img "${SINATRA_DOCKER_IMG_NM}" "${SINATRA_DOCKER_IMG_TAG}" "${SINATRA_DOCKER_CTX}" "SINATRA_HTTP_PORT=${SINATRA_HTTP_PORT}"

echo 'Image built.'
echo 'Pushing image to the ECR repostory ... '

docker_tag_image "${SINATRA_DOCKER_IMG_NM}" "${SINATRA_DOCKER_IMG_TAG}" "${SINATRA_DOCKER_REPOSITORY_URI}" "${SINATRA_DOCKER_IMG_TAG}"
docker_push_image "${SINATRA_DOCKER_REPOSITORY_URI}" "${SINATRA_DOCKER_IMG_TAG}"

echo 'Image pushed to ECR.'

docker_logout_ecr_registry "${ecr_registry_uri}" 
   
echo 'Logged out of ECR registry.' 

# Create a volume directory to mount the Sinatra sources into the container.
mkdir -p "${SINATRA_DOCKER_HOST_VOLUME_DIR}" 
chmod 700 "${SINATRA_DOCKER_HOST_VOLUME_DIR}" 

echo 'Deploying the Sinatra sources ...'

unzip -o "${SCRIPTS_DIR}"/"${SINATRA_ARCHIVE}" -d "${SINATRA_DOCKER_HOST_VOLUME_DIR}" > /dev/null
find "${SINATRA_DOCKER_HOST_VOLUME_DIR}" -type d -exec chmod 755 {} + 
find "${SINATRA_DOCKER_HOST_VOLUME_DIR}" -type f -exec chmod 744 {} +

echo 'Sinatra sources deployed.'  
echo 'Running Sinatra container ...'
  
docker_run_sinatra_container "${SINATRA_DOCKER_CONTAINER_NM}" \
                             "${SINATRA_DOCKER_REPOSITORY_URI}" \
                             "${SINATRA_DOCKER_IMG_TAG}" \
                             "${SINATRA_HTTP_PORT}" \
                             "${SINATRA_DOCKER_HOST_VOLUME_DIR}" \
                             "${SINATRA_DOCKER_CONTAINER_VOLUME_DIR}" \
                             "${SINATRA_DOCKER_CONTAINER_NETWORK_NM}"
                             
echo 'Sinatra container running.'                          
                           
echo
echo "http://${SINATRA_HTTP_ADDRESS}:${SINATRA_HTTP_PORT}/info"
echo
