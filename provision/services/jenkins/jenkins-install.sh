#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Builds a Jenkins images and push it to ECR.
############################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR='SEDscripts_dirSED'
JENKINS_DOCKER_CTX='SEDjenkins_docker_ctxSED'
JENKINS_DOCKER_REPOSITORY_URI='SEDjenkins_docker_repository_uriSED'
JENKINS_DOCKER_IMG_NM='SEDjenkins_docker_img_nmSED'
JENKINS_DOCKER_IMG_TAG='SEDjenkins_docker_img_tagSED'
JENKINS_DOCKER_CONTAINER_NM='SEDjenkins_docker_container_nmSED'
JENKINS_HTTP_PORT='SEDjenkins_http_portSED'  

source "${SCRIPTS_DIR}"/app_consts.sh
source "${SCRIPTS_DIR}"/general_utils.sh
source "${SCRIPTS_DIR}"/dockerlib.sh
source "${SCRIPTS_DIR}"/ecr.sh

yum update -y 

####
echo 'Building Jenkins ...'
####

set +e
ecr_check_repository_exists "${JENKINS_DOCKER_IMG_NM}"
set -e

repository_exists="${__RESULT}"

if [[ 'false' == "${repository_exists}" ]]
then
   ecr_create_repository "${JENKINS_DOCKER_IMG_NM}"
   
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

docker_build_img "${JENKINS_DOCKER_IMG_NM}" "${JENKINS_DOCKER_IMG_TAG}" "${JENKINS_DOCKER_CTX}" "JENKINS_HTTP_PORT=${JENKINS_HTTP_PORT}"

echo 'Image built.'
echo 'Pushing image to the ECR repostory ... '

docker_tag_image "${JENKINS_DOCKER_IMG_NM}" "${JENKINS_DOCKER_IMG_TAG}" "${JENKINS_DOCKER_REPOSITORY_URI}" "${JENKINS_DOCKER_IMG_TAG}"
docker_push_image "${JENKINS_DOCKER_REPOSITORY_URI}" "${JENKINS_DOCKER_IMG_TAG}"

echo 'Image pushed to ECR.'

docker_logout_ecr_registry "${ecr_registry_uri}" 
   
echo 'Logged out of ECR registry.'                          
echo                           

