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
REGION='SEDregionSED'
DOCKER_REPOSITORY_URI='SEDdocker_repository_uriSED'
DOCKER_IMG_NM='SEDdocker_img_nmSED'
DOCKER_IMG_TAG='SEDdocker_img_tagSED'
 
source "${SCRIPTS_DIR}"/dockerlib.sh
source "${SCRIPTS_DIR}"/ecr.sh

####
echo "Removing ${DOCKER_IMG_NM} ..."
####

#
# ECR repository
#

set +e
ecr_check_repository_exists "${DOCKER_IMG_NM}" "${REGION}"
set -e

repository_exists="${__RESULT}"

if [[ 'true' == "${repository_exists}" ]]
then
   ecr_delete_repository "${DOCKER_IMG_NM}" "${REGION}"
   
   echo 'ECR repository deleted.'
else
   echo 'ECR repository already deleted.'
fi

#
# Image
#

echo 'Deleting local images ...'

docker_check_img_exists "${DOCKER_REPOSITORY_URI}" "${DOCKER_IMG_TAG}" 
tag_exists="${__RESULT}"

if [[ 'true' == "${tag_exists}" ]]
then
   docker_delete_img "${DOCKER_REPOSITORY_URI}" "${DOCKER_IMG_TAG}" 
   
   echo 'Image tag deleted.'
else
   echo 'WARN: image tag already deleted.'
fi

docker_check_img_exists "${DOCKER_IMG_NM}" "${DOCKER_IMG_TAG}" 
image_exists="${__RESULT}"

if [[ 'true' == "${image_exists}" ]]
then
   docker_delete_img "${DOCKER_IMG_NM}" "${DOCKER_IMG_TAG}" 
   
   echo 'Image deleted.'
else
   echo 'WARN: image already deleted.'
fi

echo "${DOCKER_IMG_NM} removed."
echo

