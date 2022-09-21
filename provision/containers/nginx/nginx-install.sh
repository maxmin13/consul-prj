#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Installs Nginx server in a Docker container.
# Mounts a welcome page in the container.
# Register Nginx with the local Consul agent.
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
HTTP_ADDRESS='SEDhttp_addressSED'
HTTP_PORT='SEDhttp_portSED'  
HOST_VOLUME_DIR='SEDhost_volume_dirSED'
DOCKER_CONTAINER_VOLUME_DIR='SEDcontainer_volume_dirSED'
WEBSITE_ARCHIVE='SEDwebsite_archiveSED'
WEBSITE_NM='SEDwebsite_nmSED'
CONSUL_CONFIG_DIR="SEDconsul_config_dirSED"
CONSUL_SERVICE_FILE_NM='SEDconsul_service_file_nmSED'

source "${remote_dir}"/general_utils.sh
source "${remote_dir}"/dockerlib.sh
source "${remote_dir}"/ecr.sh
source "${remote_dir}"/consul.sh

yum update -y 

####
echo 'Running Nginx ...'
####

#
# ECR repository
#

set +e
ecr_check_repository_exists "${DOCKER_IMG_NM}" "${REGION}"
set -e

repo_exists="${__RESULT}"

if [[ 'false' == "${repo_exists}" ]]
then
   echo 'Repository not found.'
   exit  1
fi

echo 'Logging into ECR registry ...'

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

# Create a volume directory for the website to mount into the Nginx container.
mkdir -p "${HOST_VOLUME_DIR}" 
chmod 755 "${HOST_VOLUME_DIR}" 

echo 'Running container ...'

docker_run_nginx_container "${DOCKER_CONTAINER_NM}" \
                           "${DOCKER_REPOSITORY_URI}" \
                           "${DOCKER_IMG_TAG}" \
                           "${HTTP_PORT}" \
                           "${HOST_VOLUME_DIR}" \
                           "${DOCKER_CONTAINER_VOLUME_DIR}" 

echo 'Container running.'      

docker_logout_ecr_registry "${registry_uri}" 
   
echo 'Logged out of ECR registry.'     
echo 'Registering Nginx with Consul agent ...'

cd "${remote_dir}"
cp "${CONSUL_SERVICE_FILE_NM}" "${CONSUL_CONFIG_DIR}"

restart_consul_service 

echo 'Nginx registered with Consul agent.'                                             
echo 'Deploying the welcome website ...'

unzip -o "${remote_dir}"/"${WEBSITE_ARCHIVE}" -d "${HOST_VOLUME_DIR}"/"${WEBSITE_NM}"
find "${HOST_VOLUME_DIR}" -type d -exec chmod 755 {} + 
find "${HOST_VOLUME_DIR}" -type f -exec chmod 744 {} +

echo 'Welcome website deployed.'

echo
echo "http://${HTTP_ADDRESS}:${HTTP_PORT}/${WEBSITE_NM}"
echo
