#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Runs a service in a Docker container.
# Registers the container with the local Consul agent.
############################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

REMOTE_DIR='SEDremote_dirSED'
LIBRARY_DIR='SEDlibrary_dirSED' 
INSTANCE_KEY='SEDinstance_keySED'
SERVICE_KEY='SEDservice_keySED'
CONTAINER_NM='SEDcontainer_nmSED'

source "${LIBRARY_DIR}"/general_utils.sh
source "${LIBRARY_DIR}"/service_consts_utils.sh
source "${LIBRARY_DIR}"/datacenter_consts_utils.sh
source "${LIBRARY_DIR}"/dockerlib.sh
source "${LIBRARY_DIR}"/registry.sh
source "${LIBRARY_DIR}"/consul.sh

yum update -y && yum install -y jq

####
echo 'Running container ...'
####

#
# ECR repository
#

get_datacenter 'Region'
region="${__RESULT}"
get_service_image "${SERVICE_KEY}" 'Name'
image_nm="${__RESULT}"

ecr_check_repository_exists "${image_nm}" "${region}"
repository_exists="${__RESULT}"  

if [[ 'false' == "${repository_exists}" ]]
then
   echo 'Repository not found.'
   exit 1
fi

echo 'Loggin into ECR registry ...'

ecr_get_registry_uri "${region}"
registry_uri="${__RESULT}"
ecr_get_login_pwd "${region}"
login_pwd="${__RESULT}"
docker_login_ecr_registry "${registry_uri}" "${login_pwd}" 

echo 'Logged into ECR registry.'

docker_check_container_exists "${CONTAINER_NM}"
container_exists="${__RESULT}"

if [[ 'true' == "${container_exists}" ]]
then
  docker_stop_container "${CONTAINER_NM}" 
  docker_delete_container "${CONTAINER_NM}" 
  
  echo 'Container removed.'
fi

get_service_application "${SERVICE_KEY}" 'HostVolume'
volume_dir="${__RESULT}"

if [[ -n "${volume_dir}" ]]
then
   mkdir -p "${volume_dir}"
   
   get_service_application "${SERVICE_KEY}" 'ContainerUserId'
   uid="${__RESULT}" 
   
   chown -R "${uid}":"${uid}" "${volume_dir}"  
fi

echo 'Running container ...'

docker_run_container "${SERVICE_KEY}" "${CONTAINER_NM}"
docker_logout_ecr_registry "${registry_uri}" 
   
echo 'Logged out of ECR registry.'  

verify_consul_and_wait
is_ready="${__RESULT}"

if [[ 'true' == "${is_ready}" ]]
then
   echo 'Registering container with Consul agent ...'
   
   get_service_application "${SERVICE_KEY}" 'HostPort'
   application_port="${__RESULT}"

   cd "${REMOTE_DIR}"
   
   sed -e "s/SEDnameSED/${INSTANCE_KEY}/g" \
       -e "s/SEDtagsSED/${INSTANCE_KEY}/g" \
       -e "s/SEDportSED/${application_port}/g" \
          consul-register.json > /etc/consul.d/"${SERVICE_KEY}".json

   restart_consul_service 

   echo 'Container registered with Consul agent.'
else
   echo 'WARN: container not registered with Consul.'
fi

yum remove -y jq

echo
