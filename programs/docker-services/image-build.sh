#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Builds a Docker image and pushes it to the ECR registry.
############################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

LIBRARY_DIR='SEDlibrary_dirSED'
DOCKER_CTX='SEDdocker_ctxSED'
SERVICE_KEY="SEDservice_keySED"

source "${LIBRARY_DIR}"/service_consts_utils.sh
source "${LIBRARY_DIR}"/datacenter_consts_utils.sh
source "${LIBRARY_DIR}"/dockerlib.sh
source "${LIBRARY_DIR}"/registry.sh

yum update -y

####
echo "Building ${SERVICE_KEY} image ..."
####

get_datacenter 'Region'
region="${__RESULT}"
get_service_image "${SERVICE_KEY}" 'Name'
image_nm="${__RESULT}"
get_service_image "${SERVICE_KEY}" 'Tag'
image_tag="${__RESULT}"  

ecr_check_repository_exists "${image_nm}" "${region}"
repository_exists="${__RESULT}"

if [[ 'false' == "${repository_exists}" ]]
then
   ecr_create_repository "${image_nm}" "${region}"
   
   echo "${SERVICE_KEY} repository created."
else
   echo "${SERVICE_KEY} repository already created."
fi

#
# Image
#

echo "Building ${SERVICE_KEY} image ..."

docker_build_img "${image_nm}" "${image_tag}" "${DOCKER_CTX}"

echo 'Image built.'

ecr_get_registry_uri "${region}"
registry_uri="${__RESULT}"
ecr_get_repostory_uri "${image_nm}" "${registry_uri}"
repository_uri="${__RESULT}"

docker_tag_image "${image_nm}" "${image_tag}" "${repository_uri}" "${image_tag}"

echo 'Logging into ECR registry ...'

ecr_get_login_pwd "${region}"
login_pwd="${__RESULT}"
docker_login_ecr_registry "${registry_uri}" "${login_pwd}" 

echo 'Logged into ECR registry.'
echo 'Pushing image to the ECR repostory ... '

docker_push_image "${repository_uri}" "${image_tag}"

echo 'Image pushed to ECR.'
                       
docker_logout_ecr_registry "${registry_uri}" 

echo 'Logged out of ECR registry.'
echo

