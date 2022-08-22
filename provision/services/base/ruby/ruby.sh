#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Builds a Ruby base image and push it to the ECR registry.
############################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR='SEDscripts_dirSED'
RUBY_DOCKER_CTX='SEDruby_docker_ctxSED'
RUBY_DOCKER_REPOSITORY_URI='SEDruby_docker_repository_uriSED'
RUBY_DOCKER_IMG_NM='SEDruby_docker_img_nmSED'
RUBY_DOCKER_IMG_TAG='SEDruby_docker_img_tagSED'
 
source "${SCRIPTS_DIR}"/app_consts.sh
source "${SCRIPTS_DIR}"/general_utils.sh
source "${SCRIPTS_DIR}"/dockerlib.sh
source "${SCRIPTS_DIR}"/ecr.sh

yum update -y

####
STEP "Ruby"
####

#
# Ruby repository
#

set +e
ecr_check_repository_exists "${RUBY_DOCKER_IMG_NM}"
set -e

ruby_repository_exists="${__RESULT}"

if [[ 'false' == "${ruby_repository_exists}" ]]
then
   ecr_create_repository "${RUBY_DOCKER_IMG_NM}"
   
   echo 'Ruby repository created.'
else
   echo 'Ruby repository already created.'
fi

echo 'Logging into ECR registry ...'

ecr_get_registry_uri
ecr_registry_uri="${__RESULT}"
ecr_get_login_pwd
ecr_login_pwd="${__RESULT}"
docker_login_ecr_registry "${ecr_registry_uri}" "${ecr_login_pwd}" 

echo 'Logged into ECR registry.'

#
# Ruby image
#

echo 'Building Ruby image ...'

docker_build_img "${RUBY_DOCKER_IMG_NM}" "${RUBY_DOCKER_IMG_TAG}" "${RUBY_DOCKER_CTX}"

echo 'Image built.'
echo 'Pushing image to the ECR repostory ... '

docker_tag_image "${RUBY_DOCKER_IMG_NM}" "${RUBY_DOCKER_IMG_TAG}" "${RUBY_DOCKER_REPOSITORY_URI}" "${RUBY_DOCKER_IMG_TAG}"
docker_push_image "${RUBY_DOCKER_REPOSITORY_URI}" "${RUBY_DOCKER_IMG_TAG}"

echo 'Image pushed to ECR.'
                       
docker_logout_ecr_registry "${ecr_registry_uri}" 
   
echo 'Logged out of ECR registry.'
echo

