#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Installs Jenkins server in a Docker container.
# Persists Jenkins status to the host with a volume.
############################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR='/home/awsadmin/script'
JENKINS_DOCKER_CTX='/home/awsadmin/script/dockerctx'
JENKINS_DOCKER_REPOSITORY_URI='955230900736.dkr.ecr.eu-west-1.amazonaws.com/maxmin13/jenkins'
JENKINS_DOCKER_IMG_NM='maxmin13/jenkins'
JENKINS_DOCKER_IMG_TAG='v1'
JENKINS_DOCKER_CONTAINER_NM='jenkins'
JENKINS_HTTP_ADDRESS='54.154.172.186' 
JENKINS_HTTP_PORT='80'
JENKINS_INST_HOME_DIR='/var/jenkins_home'
 
source "${SCRIPTS_DIR}"/app_consts.sh
source "${SCRIPTS_DIR}"/general_utils.sh
source "${SCRIPTS_DIR}"/dockerlib.sh
source "${SCRIPTS_DIR}"/ecr.sh

yum update -y 

####
echo 'Installing Jenkins ...'
####

docker_check_container_exists "${JENKINS_DOCKER_CONTAINER_NM}"
exists="${__RESULT}"

if [[ 'true' == "${exists}" ]]
then
  docker_stop_container "${JENKINS_DOCKER_CONTAINER_NM}" 
  docker_delete_container "${JENKINS_DOCKER_CONTAINER_NM}" 
  
  echo 'Jenkins container removed.'
fi

#
# Jenkins repository
#

set +e
ecr_check_repository_exists "${JENKINS_DOCKER_IMG_NM}"
set -e

jenkins_repository_exists="${__RESULT}"

if [[ 'false' == "${jenkins_repository_exists}" ]]
then
   ecr_create_repository "${JENKINS_DOCKER_IMG_NM}"
   
   echo 'Jenkins repository created.'
else
   echo 'Jenkins repository already created.'
fi

echo 'Logging into ECR registry ...'

ecr_get_registry_uri
ecr_registry_uri="${__RESULT}"
ecr_get_login_pwd
ecr_login_pwd="${__RESULT}"
docker_login_ecr_registry "${ecr_registry_uri}" "${ecr_login_pwd}" 

echo 'Logged into ECR registry.'

#
# Jenkins image
#

echo 'Building Jenkins image ...'

docker_build_img "${JENKINS_DOCKER_IMG_NM}" "${JENKINS_DOCKER_IMG_TAG}" "${JENKINS_DOCKER_CTX}" 

echo 'Image built.'
echo 'Pushing image to the ECR repostory ... '

docker_tag_image "${JENKINS_DOCKER_IMG_NM}" "${JENKINS_DOCKER_IMG_TAG}" "${JENKINS_DOCKER_REPOSITORY_URI}" "${JENKINS_DOCKER_IMG_TAG}"
docker_push_image "${JENKINS_DOCKER_REPOSITORY_URI}" "${JENKINS_DOCKER_IMG_TAG}"

echo 'Image pushed to ECR.'

# Create a volume directory where to store Jenkins configuration.
mkdir -p "${JENKINS_INST_HOME_DIR}" 
chmod 700 "${JENKINS_INST_HOME_DIR}" 

# 1000 is the UID of the jenkins user inside the image.
chown -R 1000:1000 "${JENKINS_INST_HOME_DIR}"

echo 'Running Jenkins container ...'

docker_run_jenkins_container "${JENKINS_DOCKER_CONTAINER_NM}" \
                             "${JENKINS_DOCKER_REPOSITORY_URI}" \
                             "${JENKINS_DOCKER_IMG_TAG}" \
                             "${JENKINS_HTTP_PORT}" \
                             "${JENKINS_INST_HOME_DIR}" 
                             
echo 'Jenkins container running.'

find "${JENKINS_INST_HOME_DIR}" -type d -exec chmod 700 {} + 
find "${JENKINS_INST_HOME_DIR}" -type f -exec chmod 700 {} +
                             
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