#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Removes the Ruby base image and and its ECR repository.
############################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR='SEDscripts_dirSED'
RUBY_DOCKER_REPOSITORY_URI='SEDruby_docker_repository_uriSED'
RUBY_DOCKER_IMG_NM='SEDruby_docker_img_nmSED'
RUBY_DOCKER_IMG_TAG='SEDruby_docker_img_tagSED'
 
source "${SCRIPTS_DIR}"/app_consts.sh
source "${SCRIPTS_DIR}"/dockerlib.sh
source "${SCRIPTS_DIR}"/ecr.sh

####
echo "Ruby"
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
   ecr_delete_repository "${RUBY_DOCKER_IMG_NM}"
   
   echo 'Ruby ECR repository deleted.'
else
   echo 'Ruby ECR repository already deleted.'
fi

#
# Ruby image
#

echo 'Deleting local Ruby images ...'

docker_check_img_exists "${RUBY_DOCKER_REPOSITORY_URI}" "${RUBY_DOCKER_IMG_TAG}" 
ruby_tag_exists="${__RESULT}"

if [[ 'true' == "${ruby_tag_exists}" ]]
then
   docker_delete_img "${RUBY_DOCKER_REPOSITORY_URI}" "${RUBY_DOCKER_IMG_TAG}" 
   
   echo 'Ruby tag image deleted.'
else
   echo 'WARN: Ruby tag image already deleted.'
fi

docker_check_img_exists "${RUBY_DOCKER_REPOSITORY_URI}" "${RUBY_DOCKER_IMG_TAG}" 
ruby_exists="${__RESULT}"

if [[ 'true' == "${ruby_exists}" ]]
then
   docker_delete_img "${RUBY_DOCKER_IMG_NM}" "${RUBY_DOCKER_IMG_TAG}" 
   
   echo 'Ruby image deleted.'
else
   echo 'WARN: Ruby image already deleted.'
fi
   
echo

