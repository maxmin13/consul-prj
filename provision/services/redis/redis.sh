#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Installs a Redis database in a Docker container and runs 
# it in the default Docker bridge network.
############################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR='SEDscripts_dirSED'
REDIS_DOCKER_CTX='SEDredis_docker_ctxSED'
REDIS_DOCKER_REPOSITORY_URI='SEDredis_docker_repository_uriSED'
REDIS_DOCKER_IMG_NM='SEDredis_docker_img_nmSED'
REDIS_DOCKER_IMG_TAG='SEDredis_docker_img_tagSED'
REDIS_DOCKER_CONTAINER_NM='SEDredis_docker_container_nmSED'
REDIS_DOCKER_CONTAINER_NETWORK_NM='SEDredis_docker_container_network_nmSED'
REDIS_IP_ADDRESS='SEDredis_ip_addressSED'
REDIS_IP_PORT='SEDredis_ip_portSED'  

source "${SCRIPTS_DIR}"/app_consts.sh
source "${SCRIPTS_DIR}"/general_utils.sh
source "${SCRIPTS_DIR}"/dockerlib.sh
source "${SCRIPTS_DIR}"/ecr.sh

yum update -y 

####
echo 'Installing Redis ...'
####

docker_check_container_exists "${REDIS_DOCKER_CONTAINER_NM}"
exists="${__RESULT}"

if [[ 'true' == "${exists}" ]]
then
  docker_stop_container "${REDIS_DOCKER_CONTAINER_NM}" 
  docker_delete_container "${REDIS_DOCKER_CONTAINER_NM}" 
  
  echo 'Redis container removed.'
fi

#
# Redis repository
#

set +e
ecr_check_repository_exists "${REDIS_DOCKER_IMG_NM}"
set -e

redis_repository_exists="${__RESULT}"

if [[ 'false' == "${redis_repository_exists}" ]]
then
   ecr_create_repository "${REDIS_DOCKER_IMG_NM}"
   
   echo 'Redis repository created.'
else
   echo 'Redis repository already created.'
fi

echo 'Loggin into ECR registry ...'

ecr_get_registry_uri
ecr_registry_uri="${__RESULT}"
ecr_get_login_pwd
ecr_login_pwd="${__RESULT}"
docker_login_ecr_registry "${ecr_registry_uri}" "${ecr_login_pwd}" 

echo 'Logged into ECR registry.'

#
# Redis image
#

echo 'Building Redis image ...'

docker_build_img "${REDIS_DOCKER_IMG_NM}" "${REDIS_DOCKER_IMG_TAG}" "${REDIS_DOCKER_CTX}" "REDIS_IP_PORT=${REDIS_IP_PORT}"

echo 'Image built.'
echo 'Pushing image to the ECR repostory ... '

docker_tag_image "${REDIS_DOCKER_IMG_NM}" "${REDIS_DOCKER_IMG_TAG}" "${REDIS_DOCKER_REPOSITORY_URI}" "${REDIS_DOCKER_IMG_TAG}"
docker_push_image "${REDIS_DOCKER_REPOSITORY_URI}" "${REDIS_DOCKER_IMG_TAG}"

echo 'Image pushed to ECR.'
echo 'Running Redis container ...'

docker_run_redis_container "${REDIS_DOCKER_CONTAINER_NM}" \
                           "${REDIS_DOCKER_REPOSITORY_URI}" \
                           "${REDIS_DOCKER_IMG_TAG}" \
                           "${REDIS_IP_PORT}" \
                           "${REDIS_DOCKER_CONTAINER_NETWORK_NM}"

echo 'Redis container running.'
                           
docker_logout_ecr_registry "${ecr_registry_uri}" 
   
echo 'Logged out of ECR registry.'                             

echo 'Redis databse started.'                           
echo "redis-cli -h ${REDIS_IP_ADDRESS} -p ${REDIS_IP_PORT}"
echo
