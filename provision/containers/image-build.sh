#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Builds a Docker image and push it to the ECR registry.
############################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

remote_dir='SEDscripts_dirSED'
IMAGE_DESC='SEDimage_descSED'
REGION='SEDregionSED'
DOCKER_CTX='SEDdocker_ctxSED'
DOCKER_REPOSITORY_URI='SEDdocker_repository_uriSED'
DOCKER_IMG_NM='SEDdocker_img_nmSED'
DOCKER_IMG_TAG='SEDdocker_img_tagSED'
 
source "${remote_dir}"/general_utils.sh
source "${remote_dir}"/dockerlib.sh
source "${remote_dir}"/ecr.sh

yum update -y

####
STEP "${IMAGE_DESC}"
####

set +e
ecr_check_repository_exists "${DOCKER_IMG_NM}" ${REGION}
set -e

repository_exists="${__RESULT}"

if [[ 'false' == "${repository_exists}" ]]
then
   ecr_create_repository "${DOCKER_IMG_NM}" ${REGION}
   
   echo "${IMAGE_DESC} repository created."
else
   echo "${IMAGE_DESC} repository already created."
fi

echo 'Logging into ECR registry ...'

ecr_get_registry_uri "${REGION}"
ecr_registry_uri="${__RESULT}"
ecr_get_login_pwd "${REGION}"
ecr_login_pwd="${__RESULT}"
docker_login_ecr_registry "${ecr_registry_uri}" "${ecr_login_pwd}" 

echo 'Logged into ECR registry.'

#
# Image
#

echo "Building ${IMAGE_DESC} image ..."

docker_build_img "${DOCKER_IMG_NM}" "${DOCKER_IMG_TAG}" "${DOCKER_CTX}"

echo 'Image built.'
echo 'Pushing image to the ECR repostory ... '

docker_tag_image "${DOCKER_IMG_NM}" "${DOCKER_IMG_TAG}" "${DOCKER_REPOSITORY_URI}" "${DOCKER_IMG_TAG}"
docker_push_image "${DOCKER_REPOSITORY_URI}" "${DOCKER_IMG_TAG}"

echo 'Image pushed to ECR.'
                       
docker_logout_ecr_registry "${ecr_registry_uri}" 
   
echo 'Logged out of ECR registry.'
echo

