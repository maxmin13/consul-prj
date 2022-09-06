#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Builds a Sinatra images and push it to ECR.
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
SINATRA_HTTP_PORT='SEDsinatra_http_portSED'  

source "${SCRIPTS_DIR}"/app_consts.sh
source "${SCRIPTS_DIR}"/general_utils.sh
source "${SCRIPTS_DIR}"/dockerlib.sh
source "${SCRIPTS_DIR}"/ecr.sh

yum update -y 

####
echo 'Building Sinatra ...'
####

set +e
ecr_check_repository_exists "${SINATRA_DOCKER_IMG_NM}"
set -e

repository_exists="${__RESULT}"

if [[ 'false' == "${repository_exists}" ]]
then
   ecr_create_repository "${SINATRA_DOCKER_IMG_NM}"
   
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

docker_build_img "${SINATRA_DOCKER_IMG_NM}" "${SINATRA_DOCKER_IMG_TAG}" "${SINATRA_DOCKER_CTX}" "SINATRA_HTTP_PORT=${SINATRA_HTTP_PORT}"

echo 'Image built.'
echo 'Pushing image to the ECR repostory ... '

docker_tag_image "${SINATRA_DOCKER_IMG_NM}" "${SINATRA_DOCKER_IMG_TAG}" "${SINATRA_DOCKER_REPOSITORY_URI}" "${SINATRA_DOCKER_IMG_TAG}"
docker_push_image "${SINATRA_DOCKER_REPOSITORY_URI}" "${SINATRA_DOCKER_IMG_TAG}"

echo 'Image pushed to ECR.'

docker_logout_ecr_registry "${ecr_registry_uri}" 
   
echo 'Logged out of ECR registry.'                          
echo                           

