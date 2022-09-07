#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Runs Jenkins server in a Docker container.
# Persists Jenkins status to the host with a volume.
############################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR='SEDscripts_dirSED'
JENKINS_DOCKER_REPOSITORY_URI='SEDjenkins_docker_repository_uriSED'
JENKINS_DOCKER_IMG_NM='SEDjenkins_docker_img_nmSED'
JENKINS_DOCKER_IMG_TAG='SEDjenkins_docker_img_tagSED'
JENKINS_DOCKER_CONTAINER_NM='SEDjenkins_docker_container_nmSED'
JENKINS_HTTP_ADDRESS='SEDjenkins_http_addressSED' 
JENKINS_HTTP_PORT='SEDjenkins_http_portSED'
JENKINS_INST_HOME_DIR='SEDjenkins_inst_home_dirSED'
 
source "${SCRIPTS_DIR}"/app_consts.sh
source "${SCRIPTS_DIR}"/general_utils.sh
source "${SCRIPTS_DIR}"/dockerlib.sh
source "${SCRIPTS_DIR}"/ecr.sh

yum update -y 

####
echo 'Running Jenkins ...'
####

set +e
ecr_check_repository_exists "${JENKINS_DOCKER_IMG_NM}"
set -e

jenkins_repository_exists="${__RESULT}"

if [[ 'false' == "${jenkins_repository_exists}" ]]
then
   echo 'ERRIR: Jenkins repository not found.'
   exit 1
fi

echo 'Logging into ECR registry ...'

ecr_get_registry_uri
ecr_registry_uri="${__RESULT}"
ecr_get_login_pwd
ecr_login_pwd="${__RESULT}"
docker_login_ecr_registry "${ecr_registry_uri}" "${ecr_login_pwd}" 

echo 'Logged into ECR registry.'

docker_check_container_exists "${JENKINS_DOCKER_CONTAINER_NM}"
exists="${__RESULT}"

if [[ 'true' == "${exists}" ]]
then
  docker_stop_container "${JENKINS_DOCKER_CONTAINER_NM}" 
  docker_delete_container "${JENKINS_DOCKER_CONTAINER_NM}" 
  
  echo 'Jenkins container removed.'
fi

# Create a volume directory where to store Jenkins configuration.
mkdir -p "${JENKINS_INST_HOME_DIR}" 
chmod 700 "${JENKINS_INST_HOME_DIR}" 

# 1000 is the UID of the jenkins user inside the image.
chown -R 1000:1000 "${JENKINS_INST_HOME_DIR}"

docker_run_jenkins_container "${JENKINS_DOCKER_CONTAINER_NM}" \
                             "${JENKINS_DOCKER_REPOSITORY_URI}" \
                             "${JENKINS_DOCKER_IMG_TAG}" \
                             "${JENKINS_HTTP_PORT}" \
                             "${JENKINS_INST_HOME_DIR}" 
                             
echo 'Jenkins container running.'
                         
docker_logout_ecr_registry "${ecr_registry_uri}" 
   
echo 'Logged out of ECR registry.'

echo
echo "http://${JENKINS_HTTP_ADDRESS}:${JENKINS_HTTP_PORT}/jenkins"

if [[ -f "${JENKINS_INST_HOME_DIR}"/secrets/initialAdminPassword ]]
then
   echo
   echo 'Access code:'
   cat "${JENKINS_INST_HOME_DIR}"/secrets/initialAdminPassword
fi

echo