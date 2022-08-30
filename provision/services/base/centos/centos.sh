#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Builds a Centos 8 base image and push it to the ECR 
# registry.
############################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR='SEDscripts_dirSED'
CENTOS_DOCKER_CTX='SEDcentos_docker_ctxSED'
CENTOS_DOCKER_REPOSITORY_URI='SEDcentos_docker_repository_uriSED'
CENTOS_DOCKER_IMG_NM='SEDcentos_docker_img_nmSED'
CENTOS_DOCKER_IMG_TAG='SEDcentos_docker_img_tagSED'
 
source "${SCRIPTS_DIR}"/app_consts.sh
source "${SCRIPTS_DIR}"/general_utils.sh
source "${SCRIPTS_DIR}"/dockerlib.sh
source "${SCRIPTS_DIR}"/ecr.sh

yum update -y > /dev/null

####
STEP "Centos"
####

#
# Centos repository
#

set +e
ecr_check_repository_exists "${CENTOS_DOCKER_IMG_NM}"
set -e

centos_repository_exists="${__RESULT}"

if [[ 'false' == "${centos_repository_exists}" ]]
then
   ecr_create_repository "${CENTOS_DOCKER_IMG_NM}"
   
   echo 'Centos repository created.'
else
   echo 'Centos repository already created.'
fi

echo 'Logging into ECR registry ...'

ecr_get_registry_uri
ecr_registry_uri="${__RESULT}"
ecr_get_login_pwd
ecr_login_pwd="${__RESULT}"
docker_login_ecr_registry "${ecr_registry_uri}" "${ecr_login_pwd}" 

echo 'Logged into ECR registry.'

#
# Centos image
#

echo 'Building Centos image ...'

docker_build_img "${CENTOS_DOCKER_IMG_NM}" "${CENTOS_DOCKER_IMG_TAG}" "${CENTOS_DOCKER_CTX}"

echo 'Image built.'
echo 'Pushing image to the ECR repostory ... '

docker_tag_image "${CENTOS_DOCKER_IMG_NM}" "${CENTOS_DOCKER_IMG_TAG}" "${CENTOS_DOCKER_REPOSITORY_URI}" "${CENTOS_DOCKER_IMG_TAG}"
docker_push_image "${CENTOS_DOCKER_REPOSITORY_URI}" "${CENTOS_DOCKER_IMG_TAG}"

echo 'Image pushed to ECR.'
                       
docker_logout_ecr_registry "${ecr_registry_uri}" 
   
echo 'Logged out of ECR registry.'
echo

