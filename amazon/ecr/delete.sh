#!/bin/bash

##############################################################################################
# Creates an AWS ECR repository for a Centos base image and a ruby base image.
##############################################################################################

# shellcheck disable=SC1091,SC2155

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

####
STEP 'AWS ECR'
####

#
# Centos 
#

# Check if an ECR repository by the name of the image exists.
set +e
ecr_check_repository_exists "${CENTOS_DOCKER_IMG_NM}"
set -e

centos_repository_exists="${__RESULT}"

if [[ 'true' == "${centos_repository_exists}" ]]
then
   ecr_delete_repository "${CENTOS_DOCKER_IMG_NM}"
   
   echo 'Centos repository deleted.'
else
   echo 'Centos repository already deleted.'
fi

echo

#
# Ruby 
#

# Check if an ECR repository by the name of the image exists.
set +e
ecr_check_repository_exists "${RUBY_DOCKER_IMG_NM}"
set -e

ruby_repository_exists="${__RESULT}"

if [[ 'true' == "${ruby_repository_exists}" ]]
then
   ecr_delete_repository "${RUBY_DOCKER_IMG_NM}"
   
   echo 'Ruby repository deleted.'
else
   echo 'Ruby repository already deleted.'
fi

echo

#
# Jenkins 
#

# Check if an ECR repository by the name of the image exists.
set +e
ecr_check_repository_exists "${JENKINS_DOCKER_IMG_NM}"
set -e

jenkins_repository_exists="${__RESULT}"

if [[ 'true' == "${jenkins_repository_exists}" ]]
then
   ecr_delete_repository "${JENKINS_DOCKER_IMG_NM}"
   
   echo 'Jenkins repository deleted.'
else
   echo 'Jenkins repository already deleted.'
fi

echo

#
# Nginx 
#

# Check if an ECR repository by the name of the image exists.
set +e
ecr_check_repository_exists "${NGINX_DOCKER_IMG_NM}"
set -e

nginx_repository_exists="${__RESULT}"

if [[ 'true' == "${nginx_repository_exists}" ]]
then
   ecr_delete_repository "${NGINX_DOCKER_IMG_NM}"
   
   echo 'Nginx repository deleted.'
else
   echo 'Nginx repository already deleted.'
fi

echo

#
# Redis 
#

# Check if an ECR repository by the name of the image exists.
set +e
ecr_check_repository_exists "${REDIS_DOCKER_IMG_NM}"
set -e

redis_repository_exists="${__RESULT}"

if [[ 'true' == "${redis_repository_exists}" ]]
then
   ecr_delete_repository "${REDIS_DOCKER_IMG_NM}"
   
   echo 'Redis db repository deleted.'
else
   echo 'Redis db repository already deleted.'
fi

#
# Sinatra 
#

# Check if an ECR repository by the name of the image exists.
set +e
ecr_check_repository_exists "${SINATRA_DOCKER_IMG_NM}"
set -e

sinatra_repository_exists="${__RESULT}"

if [[ 'true' == "${sinatra_repository_exists}" ]]
then
   ecr_delete_repository "${SINATRA_DOCKER_IMG_NM}"
   
   echo 'Sinatra repository deleted.'
else
   echo 'Sinatra repository already deleted.'
fi

echo
