#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Runs a Redis database in a Docker container.
# Registers the container with the local Consul agent.
# Register Redis with the local Consul agent.
############################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

remote_dir='SEDscripts_dirSED'
REGION='SEDregionSED'
DOCKER_REPOSITORY_URI='SEDdocker_repository_uriSED'
DOCKER_IMG_NM='SEDdocker_img_nmSED'
DOCKER_IMG_TAG='SEDdocker_img_tagSED'
DOCKER_CONTAINER_NM='SEDdocker_container_nmSED'
DOCKER_CONTAINER_NETWORK_NM='SEDdocker_container_network_nmSED'
IP_ADDRESS='SEDip_addressSED'
IP_PORT='SEDip_portSED'  
CONSUL_CONFIG_DIR="SEDconsul_config_dirSED"
CONSUL_SERVICE_FILE_NM='SEDconsul_service_file_nmSED'

source "${remote_dir}"/general_utils.sh
source "${remote_dir}"/dockerlib.sh
source "${remote_dir}"/ecr.sh
source "${remote_dir}"/consul.sh

yum update -y 

####
echo 'Running Redis ...'
####

#
# ECR repository
#

set +e
ecr_check_repository_exists "${DOCKER_IMG_NM}" "${REGION}"
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

docker_check_container_exists "${DOCKER_CONTAINER_NM}"
container_exists="${__RESULT}"

if [[ 'true' == "${container_exists}" ]]
then
  docker_stop_container "${DOCKER_CONTAINER_NM}" 
  docker_delete_container "${DOCKER_CONTAINER_NM}" 
  
  echo 'Container removed.'
fi

echo 'Running Redis container ...'

docker_run_redis_container "${DOCKER_CONTAINER_NM}" \
                           "${DOCKER_REPOSITORY_URI}" \
                           "${DOCKER_IMG_TAG}" \
                           "${IP_PORT}" \
                           "${DOCKER_CONTAINER_NETWORK_NM}"

echo 'Redis container running.'
                           
docker_logout_ecr_registry "${registry_uri}" 
   
echo 'Logged out of ECR registry.'  
echo 'Registering Redis with Consul agent ...'

cd "${remote_dir}"
cp "${CONSUL_SERVICE_FILE_NM}" "${CONSUL_CONFIG_DIR}"

restart_consul_service 

echo 'Redis registered with Consul agent.'

echo                                                  
echo "redis-cli -h ${IP_ADDRESS} -p ${IP_PORT}"
echo
