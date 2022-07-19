#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Installs Nginx server in a Docker container.
# Mounts a welcome page in the container.
############################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR='SEDscripts_dirSED'
NGINX_DOCKER_CTX='SEDnginx_docker_ctxSED'
NGINX_DOCKER_REPOSITORY_URI='SEDnginx_docker_repository_uriSED'
NGINX_DOCKER_IMG_NM='SEDnginx_docker_img_nmSED'
NGINX_DOCKER_IMG_TAG='SEDnginx_docker_img_tagSED'
NGINX_DOCKER_CONTAINER_NM='SEDnginx_docker_container_nmSED'
NGINX_HTTP_ADDRESS='SEDnginx_http_addressSED'
NGINX_HTTP_PORT='SEDnginx_http_portSED'  
NGINX_INST_WEBAPPS_DIR='SEDnginx_inst_webapps_dirSED'
NGINX_WEBSITE_DIR='SEDnginx_website_dirSED'
WEBSITE_ARCHIVE='SEDwebsite_archiveSED'
WEBSITE_NM='SEDwebsite_nmSED'

source "${SCRIPTS_DIR}"/app_consts.sh
source "${SCRIPTS_DIR}"/general_utils.sh
source "${SCRIPTS_DIR}"/dockerlib.sh
source "${SCRIPTS_DIR}"/ecr.sh

yum update -y

####
echo 'Installing Nginx ...'
####

docker_check_container_exists "${NGINX_DOCKER_CONTAINER_NM}"
exists="${__RESULT}"

if [[ 'true' == "${exists}" ]]
then
  docker_stop_container "${NGINX_DOCKER_CONTAINER_NM}" 
  docker_delete_container "${NGINX_DOCKER_CONTAINER_NM}" 
  
  echo 'Nginx container removed.'
fi

#
# Nginx repository
#

set +e
ecr_check_repository_exists "${NGINX_DOCKER_IMG_NM}"
set -e

nginx_repository_exists="${__RESULT}"

if [[ 'false' == "${nginx_repository_exists}" ]]
then
   ecr_create_repository "${NGINX_DOCKER_IMG_NM}"
   
   echo 'Nginx repository created.'
else
   echo 'Nginx repository already created.'
fi

echo 'Loggin into ECR registry ...'

ecr_get_registry_uri
ecr_registry_uri="${__RESULT}"
ecr_get_login_pwd
ecr_login_pwd="${__RESULT}"
docker_login_ecr_registry "${ecr_registry_uri}" "${ecr_login_pwd}" 

echo 'Logged into ECR registry.'

#
# Nginx image
#

echo 'Building Nginx image ...'

docker_build_img "${NGINX_DOCKER_IMG_NM}" "${NGINX_DOCKER_IMG_TAG}" "${NGINX_DOCKER_CTX}" "NGINX_HTTP_PORT=${NGINX_HTTP_PORT}"

echo 'Image built.'
echo 'Pushing image to the ECR repostory ... '

docker_tag_image "${NGINX_DOCKER_IMG_NM}" "${NGINX_DOCKER_IMG_TAG}" "${NGINX_DOCKER_REPOSITORY_URI}" "${NGINX_DOCKER_IMG_TAG}"
docker_push_image "${NGINX_DOCKER_REPOSITORY_URI}" "${NGINX_DOCKER_IMG_TAG}"

echo 'Image pushed to ECR.'

# Create a volume directory for the website to mount into the Nginx container.
mkdir -p "${NGINX_INST_WEBAPPS_DIR}" 

echo 'Running Nginx container ...'

docker_run_nginx_container "${NGINX_DOCKER_CONTAINER_NM}" \
                           "${NGINX_DOCKER_REPOSITORY_URI}" \
                           "${NGINX_DOCKER_IMG_TAG}" \
                           "${NGINX_HTTP_PORT}" \
                           "${NGINX_INST_WEBAPPS_DIR}" \
                           "${NGINX_WEBSITE_DIR}" 

echo 'Nginx container running.'
                           
docker_logout_ecr_registry "${ecr_registry_uri}" 
   
echo 'Logged out of ECR registry.'                             
                           
echo 'Deploying the welcome website ...'

unzip -o "${SCRIPTS_DIR}"/"${WEBSITE_ARCHIVE}" -d "${NGINX_INST_WEBAPPS_DIR}"/"${WEBSITE_NM}"

echo 'Welcome website deployed.'

echo
echo "http://${NGINX_HTTP_ADDRESS}:${NGINX_HTTP_PORT}/${WEBSITE_NM}"
echo
