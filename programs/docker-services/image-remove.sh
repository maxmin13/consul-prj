#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Deletes the ECR repository containing the Docker image and 
# clears the local images.
############################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

LIBRARY_DIR='SEDlibrary_dirSED'
CONSTANTS_DIR='SEDconstants_dirSED'
SERVICE_KEY="SEDservice_keySED"

source "${LIBRARY_DIR}"/service_consts_utils.sh
source "${LIBRARY_DIR}"/datacenter_consts_utils.sh
source "${LIBRARY_DIR}"/dockerlib.sh
source "${LIBRARY_DIR}"/registry.sh

####
echo "Deleting ${SERVICE_KEY} image ..."
####

#
# ECR repository
#

get_datacenter 'Region'
region="${__RESULT}"
get_service_image "${SERVICE_KEY}" 'Name'
image_nm="${__RESULT}"
get_service_image "${SERVICE_KEY}" 'Tag'
image_tag="${__RESULT}"  

ecr_check_repository_exists "${image_nm}" "${region}"
repository_exists="${__RESULT}"

if [[ 'true' == "${repository_exists}" ]]
then
   ecr_delete_repository "${image_nm}" "${region}"
   
   echo 'ECR repository deleted.'
else
   echo 'ECR repository already deleted.'
fi

#
# Image
#

echo 'Deleting local images ...'

ecr_get_registry_uri "${region}"
registry_uri="${__RESULT}"
ecr_get_repostory_uri "${image_nm}" "${registry_uri}"
repository_uri="${__RESULT}"
get_service_image "${SERVICE_KEY}" 'Tag'
image_tag="${__RESULT}" 

docker_check_img_exists "${repository_uri}" "${image_tag}" 
tag_exists="${__RESULT}"

if [[ 'true' == "${tag_exists}" ]]
then
   docker_delete_img "${repository_uri}" "${image_tag}" 
   
   echo 'Image tag deleted.'
else
   echo 'WARN: image tag already deleted.'
fi

docker_check_img_exists "${image_nm}" "${image_tag}" 
image_exists="${__RESULT}"

if [[ 'true' == "${image_exists}" ]]
then
   docker_delete_img "${image_nm}" "${image_tag}" 
   
   echo 'Image deleted.'
else
   echo 'WARN: image already deleted.'
fi

echo "${image_nm} removed."
echo

