#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Builds a Nginx images and push it to ECR.
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
NGINX_HTTP_PORT='SEDnginx_http_portSED'  

source "${SCRIPTS_DIR}"/app_consts.sh
source "${SCRIPTS_DIR}"/general_utils.sh
source "${SCRIPTS_DIR}"/dockerlib.sh
source "${SCRIPTS_DIR}"/ecr.sh

yum update -y 

####
echo 'Building Nginx ...'
####

set +e
ecr_check_repository_exists "${NGINX_DOCKER_IMG_NM}"
set -e

repository_exists="${__RESULT}"

if [[ 'false' == "${repository_exists}" ]]
then
   ecr_create_repository "${NGINX_DOCKER_IMG_NM}"
   
   echo 'ECR Repository created.'
else
   echo 'ECR Repository already created.'
fi

echo 'Loggin into ECR registry ...'

ecr_get_registry_uri
ecr_registry_uri="${__RESULT}"
ecr_get_login_pwd
ecr_login_pwd="${__RESULT}"
docker_login_ecr_registry "${ecr_registry_uri}" "${ecr_login_pwd}" 

echo 'Logged into ECR registry.'

#
# Image
#

echo 'Building image ...'

docker_build_img "${NGINX_DOCKER_IMG_NM}" "${NGINX_DOCKER_IMG_TAG}" "${NGINX_DOCKER_CTX}" "NGINX_HTTP_PORT=${NGINX_HTTP_PORT}"

echo 'Image built.'
echo 'Pushing image to the ECR repostory ... '

docker_tag_image "${NGINX_DOCKER_IMG_NM}" "${NGINX_DOCKER_IMG_TAG}" "${NGINX_DOCKER_REPOSITORY_URI}" "${NGINX_DOCKER_IMG_TAG}"
docker_push_image "${NGINX_DOCKER_REPOSITORY_URI}" "${NGINX_DOCKER_IMG_TAG}"

echo 'Image pushed to ECR.'

docker_logout_ecr_registry "${ecr_registry_uri}" 
   
echo 'Logged out of ECR registry.'                          
echo                           

