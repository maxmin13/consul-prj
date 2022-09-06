#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Removes the Redis image and and its ECR repository.
############################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR='SEDscripts_dirSED'
REDIS_DOCKER_REPOSITORY_URI='SEDredis_docker_repository_uriSED'
REDIS_DOCKER_IMG_NM='SEDredis_docker_img_nmSED'
REDIS_DOCKER_IMG_TAG='SEDredis_docker_img_tagSED'
 
source "${SCRIPTS_DIR}"/app_consts.sh
source "${SCRIPTS_DIR}"/dockerlib.sh
source "${SCRIPTS_DIR}"/ecr.sh

####
echo "Redis"
####

#
# ECR repository
#

set +e
ecr_check_repository_exists "${REDIS_DOCKER_IMG_NM}"
set -e

repository_exists="${__RESULT}"

if [[ 'true' == "${repository_exists}" ]]
then
   ecr_delete_repository "${REDIS_DOCKER_IMG_NM}"
   
   echo 'ECR repository deleted.'
else
   echo 'ECR repository already deleted.'
fi

#
# Image
#

echo 'Deleting local images ...'

docker_check_img_exists "${REDIS_DOCKER_REPOSITORY_URI}" "${REDIS_DOCKER_IMG_TAG}" 
tag_exists="${__RESULT}"

if [[ 'true' == "${tag_exists}" ]]
then
   docker_delete_img "${REDIS_DOCKER_REPOSITORY_URI}" "${REDIS_DOCKER_IMG_TAG}" 
   
   echo 'Image tag deleted.'
else
   echo 'WARN: image tag already deleted.'
fi

docker_check_img_exists "${REDIS_DOCKER_IMG_NM}" "${REDIS_DOCKER_IMG_TAG}" 
image_exists="${__RESULT}"

if [[ 'true' == "${image_exists}" ]]
then
   docker_delete_img "${REDIS_DOCKER_IMG_NM}" "${REDIS_DOCKER_IMG_TAG}" 
   
   echo 'Image deleted.'
else
   echo 'WARN: image already deleted.'
fi

echo 'Local images deleted.'
echo

