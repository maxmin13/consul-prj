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
 
source "${SCRIPTS_DIR}"/app_consts.sh
source "${SCRIPTS_DIR}"/dockerlib.sh
source "${SCRIPTS_DIR}"/ecr.sh

yum update -y

####
echo "Centos"
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
   ecr_delete_repository "${CENTOS_DOCKER_IMG_NM}"
   
   echo 'Centos ECR repository deleted.'
else
   echo 'Centos ECR repository already deleted.'
fi

#
# Centos image
#

echo 'Deleting local Centos images ...'

docker_check_img_exists "${CENTOS_DOCKER_REPOSITORY_URI}" "${CENTOS_DOCKER_IMG_TAG}" 
centos_exists="${__RESULT}"

if [[ 'true' == "${centos_exists}" ]]
then
   docker_delete_img "${CENTOS_DOCKER_REPOSITORY_URI}" "${CENTOS_DOCKER_IMG_TAG}" 
   
   echo 'Centos tag image deleted.'
else
   echo 'WARN: Centos tag image already deleted.'
fi

docker_check_img_exists "${CENTOS_DOCKER_REPOSITORY_URI}" "${CENTOS_DOCKER_IMG_TAG}" 
centos_exists="${__RESULT}"

if [[ 'true' == "${centos_exists}" ]]
then
   docker_delete_img "${CENTOS_DOCKER_IMG_NM}" "${CENTOS_DOCKER_IMG_TAG}" 
   
   echo 'Centos image deleted.'
else
   echo 'WARN: Centos image already deleted.'
fi

echo 'Local Centos images deleted.'
echo

