#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Builds a Redis images and push it to ECR.
############################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR='SEDscripts_dirSED'
REDIS_DOCKER_CTX='SEDredis_docker_ctxSED'
REDIS_DOCKER_REPOSITORY_URI='SEDredis_docker_repository_uriSED'
REDIS_DOCKER_IMG_NM='SEDredis_docker_img_nmSED'
REDIS_DOCKER_IMG_TAG='SEDredis_docker_img_tagSED'
REDIS_IP_PORT='SEDredis_ip_portSED'  

source "${SCRIPTS_DIR}"/app_consts.sh
source "${SCRIPTS_DIR}"/general_utils.sh
source "${SCRIPTS_DIR}"/dockerlib.sh
source "${SCRIPTS_DIR}"/ecr.sh

yum update -y 

####
echo 'Building Redis ...'
####

set +e
ecr_check_repository_exists "${REDIS_DOCKER_IMG_NM}"
set -e

repository_exists="${__RESULT}"

if [[ 'false' == "${repository_exists}" ]]
then
   ecr_create_repository "${REDIS_DOCKER_IMG_NM}"
   
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

docker_build_img "${REDIS_DOCKER_IMG_NM}" "${REDIS_DOCKER_IMG_TAG}" "${REDIS_DOCKER_CTX}" "REDIS_IP_PORT=${REDIS_IP_PORT}"

echo 'Image built.'
echo 'Pushing image to the ECR repostory ... '

docker_tag_image "${REDIS_DOCKER_IMG_NM}" "${REDIS_DOCKER_IMG_TAG}" "${REDIS_DOCKER_REPOSITORY_URI}" "${REDIS_DOCKER_IMG_TAG}"
docker_push_image "${REDIS_DOCKER_REPOSITORY_URI}" "${REDIS_DOCKER_IMG_TAG}"

echo 'Image pushed to ECR.'

docker_logout_ecr_registry "${ecr_registry_uri}" 
   
echo 'Logged out of ECR registry.'                          
echo                           

