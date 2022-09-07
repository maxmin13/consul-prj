#!/bin/bash

# shellcheck disable=SC2015

#####################################################
# Install a Sinatra server in a Docker container.
#####################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR=/home/"${USER_NM}"/script
SINATRA_ARCHIVE='webapp.zip'
SINATRA_DOCKER_CONTAINER_NETWORK_NM='bridge'

####
STEP 'Sinatra web'
####

get_datacenter_id "${DTC_NM}"
dtc_id="${__RESULT}"
  
if [[ -z "${dtc_id}" ]]
then
   echo '* ERROR: data center not found.'
   exit 1
else
   echo "* data center ID: ${dtc_id}."
fi

get_subnet_id "${DTC_SUBNET_MAIN_NM}"
subnet_id="${__RESULT}"

if [[ -z "${subnet_id}" ]]
then
   echo '* ERROR: main subnet not found.'
   exit 1
else
   echo "* main subnet ID: ${subnet_id}."
fi

get_instance_id "${SINATRA_INST_NM}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* ERROR: Sinatra box not found.'
   exit 1
fi

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${SINATRA_INST_NM}"
   instance_st="${__RESULT}"
   
   if [[ 'running' == "${instance_st}" ]]
   then
      echo "* Sinatra box ready (${instance_st})."
   else
      echo "* ERROR: Sinatra box is not ready. (${instance_st})."
      
      exit 1
   fi
fi

# Get the public IP address assigned to the instance. 
get_public_ip_address_associated_with_instance "${SINATRA_INST_NM}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo '* ERROR: Sinatra IP address not found.'
   exit 1
else
   echo "* Sinatra IP address: ${eip}."
fi

get_security_group_id "${SINATRA_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* ERROR: security group not found.'
   exit 1
else
   echo "* security group ID: ${sgp_id}."
fi

# Jumpbox where Consul server is installed.
get_instance_id "${ADMIN_INST_NM}"
admin_instance_id="${__RESULT}"

if [[ -z "${admin_instance_id}" ]]
then
   echo '* ERROR: Admin box not found.'
   exit 1
fi

if [[ -n "${admin_instance_id}" ]]
then
   get_instance_state "${ADMIN_INST_NM}"
   admin_instance_st="${__RESULT}"
   
   if [[ 'running' == "${admin_instance_st}" ]]
   then
      echo "* Admin box ready (${admin_instance_st})."
   else
      echo "* ERROR: Admin box not ready. (${admin_instance_st})."
      
      exit 1
   fi
fi

get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}"
admin_eip="${__RESULT}"

if [[ -z "${admin_eip}" ]]
then
   echo '* ERROR: Admin IP address not found.'
   exit 1
else
   echo "* Admin IP address: ${admin_eip}."
fi

###### TODO check consul client installed
###### TODO
###### TODO

# Removing old files
# shellcheck disable=SC2115
sinatra_tmp_dir="${TMP_DIR}"/sinatra
rm -rf  "${sinatra_tmp_dir:?}"
mkdir -p "${sinatra_tmp_dir}"

echo

#
# Firewall
#

check_access_is_granted "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/sinatra.log  
   
   echo "Access granted on ${SHARED_INST_SSH_PORT} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted on ${SHARED_INST_SSH_PORT} tcp 0.0.0.0/0."
fi

#
# Permissions.
#

check_role_has_permission_policy_attached "${SINATRA_AWS_ROLE_NM}" "${ECR_POLICY_NM}"
is_permission_policy_associated="${__RESULT}"

if [[ 'false' == "${is_permission_policy_associated}" ]]
then
   echo 'Attaching permission policy to the role ...'

   attach_permission_policy_to_role "${SINATRA_AWS_ROLE_NM}" "${ECR_POLICY_NM}"
      
   echo 'Permission policy associated to the role.' 
else
   echo 'WARN: permission policy already associated to the role.'
fi    

#
echo 'Provisioning the instance ...'
# 

private_key_file="${ACCESS_DIR}"/"${SINATRA_INST_KEY_PAIR_NM}" 
wait_ssh_started "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}"

ssh_run_remote_command "rm -rf ${SCRIPTS_DIR:?} && mkdir -p ${SCRIPTS_DIR}/sinatra" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}"  

# Prepare the scripts to run on the server.

ecr_get_repostory_uri "${SINATRA_DOCKER_IMG_NM}"
sinatra_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}"/sinatra)/g" \
    -e "s/SEDsinatra_docker_repository_uriSED/$(escape "${sinatra_docker_repository_uri}")/g" \
    -e "s/SEDsinatra_docker_img_nmSED/$(escape "${SINATRA_DOCKER_IMG_NM}")/g" \
    -e "s/SEDsinatra_docker_img_tagSED/${SINATRA_DOCKER_IMG_TAG}/g" \
    -e "s/SEDsinatra_docker_container_nmSED/${SINATRA_DOCKER_CONTAINER_NM}/g" \
    -e "s/SEDsinatra_docker_container_volume_dirSED/$(escape "${SINATRA_DOCKER_CONTAINER_VOLUME_DIR}")/g" \
    -e "s/SEDsinatra_docker_host_volume_dirSED/$(escape "${SINATRA_DOCKER_HOST_VOLUME_DIR}")/g" \
    -e "s/SEDsinatra_docker_container_network_nmSED/${SINATRA_DOCKER_CONTAINER_NETWORK_NM}/g" \
    -e "s/SEDsinatra_http_addressSED/${eip}/g" \
    -e "s/SEDsinatra_http_portSED/${SINATRA_HTTP_PORT}/g" \
    -e "s/SEDsinatra_archiveSED/${SINATRA_ARCHIVE}/g" \
       "${SERVICES_DIR}"/sinatra/sinatra-run.sh > "${sinatra_tmp_dir}"/sinatra-run.sh  
                        
echo 'sinatra-run.sh ready.'  

# The Sinatra image is built from a base Ruby image.
ecr_get_repostory_uri "${RUBY_DOCKER_IMG_NM}"
ruby_docker_repository_uri="${__RESULT}"

sed -e "s/SEDrepository_uriSED/$(escape "${ruby_docker_repository_uri}")/g" \
    -e "s/SEDimg_tagSED/${RUBY_DOCKER_IMG_TAG}/g" \
    -e "s/SEDcontainer_volume_dirSED/$(escape "${SINATRA_DOCKER_CONTAINER_VOLUME_DIR}")/g" \
       "${SERVICES_DIR}"/sinatra/Dockerfile > "${sinatra_tmp_dir}"/Dockerfile

echo 'Dockerfile ready.' 

## Sinatra webapp
cd "${sinatra_tmp_dir}" || exit
cp -R "${SERVICES_DIR}"/sinatra/webapp .
zip -r "${SINATRA_ARCHIVE}" webapp >> "${LOGS_DIR}"/sinatra.log

echo "${SINATRA_ARCHIVE} ready." 
    
scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}"/sinatra \
    "${LIBRARY_DIR}"/constants/app_consts.sh \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${sinatra_tmp_dir}"/sinatra-run.sh \
    "${sinatra_tmp_dir}"/"${SINATRA_ARCHIVE}" 

ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR}"/sinatra \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" 
    
ssh_run_remote_command_as_root "${SCRIPTS_DIR}/sinatra/sinatra-run.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}">> "${LOGS_DIR}"/sinatra.log && echo 'Sinatra web successfully installed.' ||
    {
    
       echo 'The role may not have been associated to the profile yet.'
       echo 'Let''s wait a bit and check again (first time).' 
      
       wait 180  
      
       echo 'Let''s try now.' 
    
       ssh_run_remote_command_as_root "${SCRIPTS_DIR}/sinatra/sinatra-run.sh" \
          "${private_key_file}" \
          "${eip}" \
          "${SHARED_INST_SSH_PORT}" \
          "${USER_NM}" \
          "${USER_PWD}" >> "${LOGS_DIR}"/sinatra.log && echo 'Sinatra web successfully installed.' ||
          {
              echo 'ERROR: the problem persists after 3 minutes.'
              exit 1          
          }
    }

ssh_run_remote_command "rm -rf ${SCRIPTS_DIR:?}" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" 
    
#
# Permissions.
#

check_role_has_permission_policy_attached "${SINATRA_AWS_ROLE_NM}" "${ECR_POLICY_NM}"
is_permission_policy_associated="${__RESULT}"

if [[ 'true' == "${is_permission_policy_associated}" ]]
then
   echo 'Detaching permission policy from role ...'
   
   detach_permission_policy_from_role "${SINATRA_AWS_ROLE_NM}" "${ECR_POLICY_NM}"
      
   echo 'Permission policy detached.'
else
   echo 'WARN: permission policy already detached from the role.'
fi 

## 
## Firewall.
##

check_access_is_granted "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'true' == "${is_granted}" ]]
then
   revoke_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/sinatra.log 
   
   echo "Access revoked on ${SHARED_INST_SSH_PORT} tcp 0.0.0.0/0."
else
   echo "WARN: access already revoked ${SHARED_INST_SSH_PORT} tcp 0.0.0.0/0."
fi

check_access_is_granted "${sgp_id}" "${SINATRA_HTTP_PORT}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${SINATRA_HTTP_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/sinatra.log  
   
   echo "Access granted on ${SINATRA_HTTP_PORT} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted on ${SINATRA_HTTP_PORT} tcp 0.0.0.0/0."
fi
    
echo "http://${eip}:${SINATRA_HTTP_PORT}/info"
echo    

# Removing old files
# shellcheck disable=SC2115
rm -rf  "${sinatra_tmp_dir:?}"
    
echo 'Sinatra web created.'
echo

