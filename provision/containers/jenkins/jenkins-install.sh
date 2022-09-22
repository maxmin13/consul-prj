#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Runs Jenkins server in a Docker container.
# Persists Jenkins status to the host with a volume.
# Register Jenkins with the local Consul agent.
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
HTTP_ADDRESS='SEDhttp_addressSED' 
HTTP_PORT='SEDhttp_portSED'
HOST_VOLUME_DIR='SEDhost_volume_dirSED'
CONSUL_CONFIG_DIR="SEDconsul_config_dirSED"
CONSUL_SERVICE_FILE_NM='SEDconsul_service_file_nmSED'
 
source "${remote_dir}"/general_utils.sh
source "${remote_dir}"/dockerlib.sh
source "${remote_dir}"/ecr.sh
source "${remote_dir}"/consul.sh

yum update -y 

####
echo 'Running Jenkins ...'
####

ecr_check_repository_exists "${DOCKER_IMG_NM}" "${REGION}"
repository_exists="${__RESULT}"

if [[ 'false' == "${repository_exists}" ]]
then
   echo 'ERRIR: Jenkins repository not found.'
   exit 1
fi

echo 'Logging into ECR registry ...'

ecr_get_registry_uri "${REGION}" 
registry_uri="${__RESULT}"
ecr_get_login_pwd "${REGION}"
login_pwd="${__RESULT}"
docker_login_ecr_registry "${registry_uri}" "${login_pwd}" 

echo 'Logged into ECR registry.'

docker_check_container_exists "${DOCKER_CONTAINER_NM}"
exists="${__RESULT}"

if [[ 'true' == "${exists}" ]]
then
  docker_stop_container "${DOCKER_CONTAINER_NM}" 
  docker_delete_container "${DOCKER_CONTAINER_NM}" 
  
  echo 'Jenkins container removed.'
fi

# Create a volume directory where to store Jenkins configuration.
mkdir -p "${HOST_VOLUME_DIR}" 
chmod 700 "${HOST_VOLUME_DIR}" 

# 1000 is the UID of the jenkins user inside the image.
chown -R 1000:1000 "${HOST_VOLUME_DIR}"

docker_run_jenkins_container "${DOCKER_CONTAINER_NM}" \
                             "${DOCKER_REPOSITORY_URI}" \
                             "${DOCKER_IMG_TAG}" \
                             "${HTTP_PORT}" \
                             "${HOST_VOLUME_DIR}" 
                             
echo 'Jenkins container running.'
                         
docker_logout_ecr_registry "${registry_uri}" 
   
echo 'Logged out of ECR registry.'     
echo 'Registering Jenkins with Consul agent ...'

cd "${remote_dir}"
cp "${CONSUL_SERVICE_FILE_NM}" "${CONSUL_CONFIG_DIR}"

restart_consul_service

echo 'Jenkins registered with Consul agent.'           

echo
echo "http://${HTTP_ADDRESS}:${HTTP_PORT}/jenkins"

if [[ -f "${HOST_VOLUME_DIR}"/secrets/initialAdminPassword ]]
then
   echo
   echo 'Access code:'
   cat "${HOST_VOLUME_DIR}"/secrets/initialAdminPassword
fi

echo
