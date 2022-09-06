#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Removes the Jenkins image and and its ECR repository.
############################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR='SEDscripts_dirSED'
JENKINS_DOCKER_REPOSITORY_URI='SEDjenkins_docker_repository_uriSED'
JENKINS_DOCKER_IMG_NM='SEDjenkins_docker_img_nmSED'
JENKINS_DOCKER_IMG_TAG='SEDjenkins_docker_img_tagSED'
BASE_JENKINS_DOCKER_IMG_NM='SEDbase_jenkins_docker_img_nmSED'
BASE_JENKINS_DOCKER_IMG_TAG='SEDbase_jenkins_docker_img_tagSED'
 
source "${SCRIPTS_DIR}"/app_consts.sh
source "${SCRIPTS_DIR}"/dockerlib.sh
source "${SCRIPTS_DIR}"/ecr.sh

####
echo "Jenkins"
####

#
# ECR repository
#

set +e
ecr_check_repository_exists "${JENKINS_DOCKER_IMG_NM}"
set -e

repository_exists="${__RESULT}"

if [[ 'true' == "${repository_exists}" ]]
then
   ecr_delete_repository "${JENKINS_DOCKER_IMG_NM}"
   
   echo 'ECR repository deleted.'
else
   echo 'ECR repository already deleted.'
fi

#
# Image
#

echo 'Deleting local images ...'

docker_check_img_exists "${JENKINS_DOCKER_REPOSITORY_URI}" "${JENKINS_DOCKER_IMG_TAG}" 
tag_exists="${__RESULT}"

if [[ 'true' == "${tag_exists}" ]]
then
   docker_delete_img "${JENKINS_DOCKER_REPOSITORY_URI}" "${JENKINS_DOCKER_IMG_TAG}" 
   
   echo 'Image tag deleted.'
else
   echo 'WARN: image tag already deleted.'
fi

docker_check_img_exists "${JENKINS_DOCKER_IMG_NM}" "${JENKINS_DOCKER_IMG_TAG}" 
image_exists="${__RESULT}"

if [[ 'true' == "${image_exists}" ]]
then
   docker_delete_img "${JENKINS_DOCKER_IMG_NM}" "${JENKINS_DOCKER_IMG_TAG}" 
   
   echo 'Image deleted.'
else
   echo 'WARN: image already deleted.'
fi

docker_check_img_exists "${BASE_JENKINS_DOCKER_IMG_NM}" "${BASE_JENKINS_DOCKER_IMG_TAG}" 
base_exists="${__RESULT}"

if [[ 'true' == "${base_exists}" ]]
then
   docker_delete_img "${BASE_JENKINS_DOCKER_IMG_NM}" "${BASE_JENKINS_DOCKER_IMG_TAG}" 
   
   echo 'Base image deleted.'
else
   echo 'WARN: base image already deleted.'
fi

echo 'Local images deleted.'
echo

