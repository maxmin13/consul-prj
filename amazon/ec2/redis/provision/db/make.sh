#!/bin/bash

# shellcheck disable=SC2015

#####################################################
# Creates an EC2 Linux box.
# Install a Redis database in a Docker container.
# The database runs in a bridge network.
#####################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR=/home/"${USER_NM}"/script
REDIS_DOCKER_CONTAINER_NETWORK_NM='bridge'

####
STEP 'Redis database'
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

get_instance_id "${REDIS_INST_NM}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* ERROR: Redis box not found.'
   exit 1
fi

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${REDIS_INST_NM}"
   instance_st="${__RESULT}"
   
   if [[ 'running' == "${instance_st}" ]]
   then
      echo "* Redis box ready (${instance_st})."
   else
      echo "* ERROR: Redis box is not ready. (${instance_st})."
      
      exit 1
   fi
fi

# Get the public IP address assigned to the instance. 
get_public_ip_address_associated_with_instance "${REDIS_INST_NM}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo '* ERROR: Redis IP address not found.'
   exit 1
else
   echo "* Redis IP address: ${eip}."
fi

get_security_group_id "${REDIS_INST_SEC_GRP_NM}"
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
redis_tmp_dir="${TMP_DIR}"/consul
rm -rf  "${redis_tmp_dir:?}"
mkdir -p "${redis_tmp_dir}"

echo

#
# Firewall
#

get_security_group_id "${REDIS_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

check_access_is_granted "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log  
   
   echo "Access granted on ${SHARED_INST_SSH_PORT} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted on ${SHARED_INST_SSH_PORT} tcp 0.0.0.0/0."
fi
   
echo 'Granted SSH access to the box.'

#
# Permissions.
#

check_role_has_permission_policy_attached "${REDIS_AWS_ROLE_NM}" "${ECR_POLICY_NM}"
is_permission_policy_associated="${__RESULT}"

if [[ 'false' == "${is_permission_policy_associated}" ]]
then
   echo 'Attaching permission policy to the role ...'

   attach_permission_policy_to_role "${REDIS_AWS_ROLE_NM}" "${ECR_POLICY_NM}"

   echo 'Permission policy associated to the role.'  
else
   echo 'WARN: permission policy already associated to the role.'
fi 

#
echo 'Provisioning the instance ...'
# 

private_key_file="${ACCESS_DIR}"/"${REDIS_INST_KEY_PAIR_NM}" 
wait_ssh_started "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}"

ssh_run_remote_command "rm -rf ${SCRIPTS_DIR:?} && mkdir -p ${SCRIPTS_DIR}/redis/dockerctx" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}"  

# Prepare the scripts to run on the server.

ecr_get_repostory_uri "${REDIS_DOCKER_IMG_NM}"
redis_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}"/redis)/g" \
    -e "s/SEDredis_docker_repository_uriSED/$(escape "${redis_docker_repository_uri}")/g" \
    -e "s/SEDredis_docker_img_nmSED/$(escape "${REDIS_DOCKER_IMG_NM}")/g" \
    -e "s/SEDredis_docker_img_tagSED/${REDIS_DOCKER_IMG_TAG}/g" \
    -e "s/SEDredis_docker_container_nmSED/${REDIS_DOCKER_CONTAINER_NM}/g" \
    -e "s/SEDredis_docker_container_network_nmSED/${REDIS_DOCKER_CONTAINER_NETWORK_NM}/g" \
    -e "s/SEDredis_ip_addressSED/${eip}/g" \
    -e "s/SEDredis_ip_portSED/${REDIS_IP_PORT}/g" \
       "${SERVICES_DIR}"/redis/redis-run.sh > "${redis_tmp_dir}"/redis-run.sh  
  
echo 'redis-run.sh ready.'  

# The Redis image is built from a base Centos image.
ecr_get_repostory_uri "${CENTOS_DOCKER_IMG_NM}"
centos_docker_repository_uri="${__RESULT}"

sed -e "s/SEDrepository_uriSED/$(escape "${centos_docker_repository_uri}")/g" \
    -e "s/SEDimg_tagSED/${CENTOS_DOCKER_IMG_TAG}/g" \
       "${SERVICES_DIR}"/redis/Dockerfile > "${redis_tmp_dir}"/Dockerfile

echo 'Dockerfile ready.'
   
scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}"/redis/dockerctx \
    "${redis_tmp_dir}"/Dockerfile \
    "${SERVICES_DIR}"/redis/redis.conf
    
scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}"/redis \
    "${LIBRARY_DIR}"/constants/app_consts.sh \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${redis_tmp_dir}"/redis-run.sh

ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR}"/redis \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" 
    
ssh_run_remote_command_as_root "${SCRIPTS_DIR}/redis/redis-run.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" >> "${LOGS_DIR}"/redis.log && echo 'Redis database successfully installed.' ||
    {    
       echo 'The role may not have been associated to the profile yet.'
       echo 'Let''s wait a bit and check again (first time).' 
      
       wait 180  
      
       echo 'Let''s try now.' 
    
       ssh_run_remote_command_as_root "${SCRIPTS_DIR}/redis/redis-run.sh" \
          "${private_key_file}" \
          "${eip}" \
          "${SHARED_INST_SSH_PORT}" \
          "${USER_NM}" \
          "${USER_PWD}" >> "${LOGS_DIR}"/redis.log && echo 'Redis database successfully installed.' ||
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

check_role_has_permission_policy_attached "${REDIS_AWS_ROLE_NM}" "${ECR_POLICY_NM}"
is_permission_policy_associated="${__RESULT}"

if [[ 'true' == "${is_permission_policy_associated}" ]]
then
   echo 'Detaching permission policy from role ...'
   
   detach_permission_policy_from_role "${REDIS_AWS_ROLE_NM}" "${ECR_POLICY_NM}"
      
   echo 'Permission policy detached.'
else
   echo 'WARN: permission policy already detached from the role.'
fi 

## 
## Firewall
##

check_access_is_granted "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'true' == "${is_granted}" ]]
then
   revoke_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log  
   
   echo "Access revoked on ${SHARED_INST_SSH_PORT} tcp 0.0.0.0/0."
else
   echo "WARN: access already revoked ${SHARED_INST_SSH_PORT} tcp 0.0.0.0/0."
fi

# Removing old files
# shellcheck disable=SC2115
rm -rf  "${redis_tmp_dir:?}"

echo 'Redis database installed.'
echo

