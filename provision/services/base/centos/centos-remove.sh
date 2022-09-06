#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Removes the Centos 8 base image and and its ECR 
# repository.
############################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR='SEDscripts_dirSED'
CENTOS_DOCKER_REPOSITORY_URI='SEDcentos_docker_repository_uriSED'
CENTOS_DOCKER_IMG_NM='SEDcentos_docker_img_nmSED'
CENTOS_DOCKER_IMG_TAG='SEDcentos_docker_img_tagSED'
BASE_CENTOS_DOCKER_IMG_NM='SEDbase_centos_docker_img_nmSED'
BASE_CENTOS_DOCKER_IMG_TAG='SEDbase_centos_docker_img_tagSED'
 
source "${SCRIPTS_DIR}"/app_consts.sh
source "${SCRIPTS_DIR}"/dockerlib.sh
source "${SCRIPTS_DIR}"/ecr.sh

yum update -y

####
echo "Centos"
####

#
# ECR repository
#

set +e
ecr_check_repository_exists "${CENTOS_DOCKER_IMG_NM}"
set -e

repository_exists="${__RESULT}"

if [[ 'true' == "${repository_exists}" ]]
then
   ecr_delete_repository "${CENTOS_DOCKER_IMG_NM}"
   
   echo 'ECR repository deleted.'
else
   echo 'ECR repository already deleted.'
fi

#
# image
#

echo 'Deleting local images ...'

docker_check_img_exists "${CENTOS_DOCKER_REPOSITORY_URI}" "${CENTOS_DOCKER_IMG_TAG}" 
tag_exists="${__RESULT}"

if [[ 'true' == "${tag_exists}" ]]
then
   docker_delete_img "${CENTOS_DOCKER_REPOSITORY_URI}" "${CENTOS_DOCKER_IMG_TAG}" 
   
   echo 'Image tag deleted.'
else
   echo 'WARN: image tag already deleted.'
fi

docker_check_img_exists "${CENTOS_DOCKER_IMG_NM}" "${CENTOS_DOCKER_IMG_TAG}" 
image_exists="${__RESULT}"

if [[ 'true' == "${image_exists}" ]]
then
   docker_delete_img "${CENTOS_DOCKER_IMG_NM}" "${CENTOS_DOCKER_IMG_TAG}" 
   
   echo 'Image deleted.'
else
   echo 'WARN: image already deleted.'
fi

docker_check_img_exists "${BASE_CENTOS_DOCKER_IMG_NM}" "${BASE_CENTOS_DOCKER_IMG_TAG}" 
base_exists="${__RESULT}"

if [[ 'true' == "${base_exists}" ]]
then
   docker_delete_img "${BASE_CENTOS_DOCKER_IMG_NM}" "${BASE_CENTOS_DOCKER_IMG_TAG}" 
   
   echo 'Base image deleted.'
else
   echo 'WARN: base image already deleted.'
fi

echo 'Local images deleted.'
echo

