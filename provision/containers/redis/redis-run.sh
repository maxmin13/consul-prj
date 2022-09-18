#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Runs a Redis database in a Docker container.
# Registers the container with Consul cluster.
############################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR='SEDscripts_dirSED'
REGION='SEDregionSED'
REDIS_DOCKER_REPOSITORY_URI='SEDredis_docker_repository_uriSED'
REDIS_DOCKER_IMG_NM='SEDredis_docker_img_nmSED'
REDIS_DOCKER_IMG_TAG='SEDredis_docker_img_tagSED'
REDIS_DOCKER_CONTAINER_NM='SEDredis_docker_container_nmSED'
REDIS_DOCKER_CONTAINER_NETWORK_NM='SEDredis_docker_container_network_nmSED'
REDIS_IP_ADDRESS='SEDredis_ip_addressSED'
REDIS_IP_PORT='SEDredis_ip_portSED'  

source "${SCRIPTS_DIR}"/general_utils.sh
source "${SCRIPTS_DIR}"/dockerlib.sh
source "${SCRIPTS_DIR}"/ecr.sh

yum update -y 

####
echo 'Running Redis ...'
####

#
# ECR repository
#

set +e
ecr_check_repository_exists "${REDIS_DOCKER_IMG_NM}" "${REGION}"
set -e

repository_exists="${__RESULT}"

if [[ 'false' == "${repository_exists}" ]]
then
   echo 'Repository not found.'
   exit  1
fi

echo 'Loggin into ECR registry ...'

ecr_get_registry_uri "${REGION}"
registry_uri="${__RESULT}"
ecr_get_login_pwd "${REGION}"
login_pwd="${__RESULT}"
docker_login_ecr_registry "${registry_uri}" "${login_pwd}" 

echo 'Logged into ECR registry.'

docker_check_container_exists "${REDIS_DOCKER_CONTAINER_NM}"
container_exists="${__RESULT}"

if [[ 'true' == "${container_exists}" ]]
then
  docker_stop_container "${REDIS_DOCKER_CONTAINER_NM}" 
  docker_delete_container "${REDIS_DOCKER_CONTAINER_NM}" 
  
  echo 'Container removed.'
fi

echo 'Running Redis container ...'

docker_run_redis_container "${REDIS_DOCKER_CONTAINER_NM}" \
                           "${REDIS_DOCKER_REPOSITORY_URI}" \
                           "${REDIS_DOCKER_IMG_TAG}" \
                           "${REDIS_IP_PORT}" \
                           "${REDIS_DOCKER_CONTAINER_NETWORK_NM}"

echo 'Redis container running.'
                           
docker_logout_ecr_registry "${registry_uri}" 
   
echo 'Logged out of ECR registry.'  
echo                                                  
echo "redis-cli -h ${REDIS_IP_ADDRESS} -p ${REDIS_IP_PORT}"
echo
