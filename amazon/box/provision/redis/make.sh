#!/bin/bash

# shellcheck disable=SC2015

#####################################################
# Install a Redis database in a Docker container.
#####################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# Enforce parameter
if [ "$#" -lt 1 ]; then
  echo "USAGE: instance_key"
  echo "EXAMPLE: admin"
  echo "Only provided $# arguments"
  exit 1
fi

instance_key="${1}"
logfile_nm="${instance_key}".log
REDIS_DOCKER_CONTAINER_NETWORK_NM='bridge'

####
STEP "${instance_key} box provision Redis database."
####

get_instance_name "${instance_key}"
instance_nm="${__RESULT}"
instance_is_running "${instance_nm}"
is_running="${__RESULT}"
get_instance_state "${instance_nm}"
instance_st="${__RESULT}"

if [[ 'true' == "${is_running}" ]]
then
   echo "* ${instance_key} box ready (${instance_st})."
else
   echo "* WARN: ${instance_key} box is not ready (${instance_st})."
      
   return 0
fi

# Get the public IP address assigned to the instance. 
get_public_ip_address_associated_with_instance "${instance_nm}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo "* ERROR: ${instance_key} IP address not found."
   exit 1
else
   echo "* ${instance_key} IP address: ${eip}."
fi

get_security_group_name "${instance_key}"
sgp_nm="${__RESULT}"
get_security_group_id "${sgp_nm}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* ERROR: security group not found.'
   exit 1
else
   echo "* security group ID: ${sgp_id}."
fi

echo

temporary_dir="${TMP_DIR}"/"${instance_key}"
rm -rf  "${temporary_dir:?}"
mkdir -p "${temporary_dir}"

#
# Firewall
#

get_application_port 'ssh'
ssh_port="${__RESULT}"

check_access_is_granted "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"  
   
   echo "Access granted on ${ssh_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted on ${ssh_port} tcp 0.0.0.0/0."
fi
   
#
# Permissions.
#

get_role_name "${instance_key}"
role_nm="${__RESULT}"
check_role_has_permission_policy_attached "${role_nm}" "${ECR_POLICY_NM}"
is_permission_policy_associated="${__RESULT}"

if [[ 'false' == "${is_permission_policy_associated}" ]]
then
   echo "Associating permission policy to the ${instance_key} role ..."

   attach_permission_policy_to_role "${role_nm}" "${ECR_POLICY_NM}"

   echo "Permission policy associated to the ${instance_key} role."
else
   echo "WARN: permission policy already associated to the ${instance_key} role."
fi 

#
echo "Provisioning ${instance_key} instance ..."
# 

get_keypair_name "${instance_key}"
keypair_nm="${__RESULT}"
private_key_file="${ACCESS_DIR}"/"${keypair_nm}" 
wait_ssh_started "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}"

get_user_name
user_nm="${__RESULT}"
remote_dir=/home/"${user_nm}"/script

ssh_run_remote_command "rm -rf ${remote_dir:?} && mkdir -p ${remote_dir}/redis" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"  

# Prepare the scripts to run on the server.

get_region_name
region="${__RESULT}"
ecr_get_registry_uri "${region}"
registry_uri="${__RESULT}"
ecr_get_repostory_uri "${REDIS_DOCKER_IMG_NM}" "${registry_uri}"
redis_docker_repository_uri="${__RESULT}"
get_application_port 'redis'
redis_port="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${remote_dir}"/redis)/g" \
    -e "s/SEDregionSED/${region}/g" \
    -e "s/SEDredis_docker_repository_uriSED/$(escape "${redis_docker_repository_uri}")/g" \
    -e "s/SEDredis_docker_img_nmSED/$(escape "${REDIS_DOCKER_IMG_NM}")/g" \
    -e "s/SEDredis_docker_img_tagSED/${REDIS_DOCKER_IMG_TAG}/g" \
    -e "s/SEDredis_docker_container_nmSED/${REDIS_DOCKER_CONTAINER_NM}/g" \
    -e "s/SEDredis_docker_container_network_nmSED/${REDIS_DOCKER_CONTAINER_NETWORK_NM}/g" \
    -e "s/SEDredis_ip_addressSED/${eip}/g" \
    -e "s/SEDredis_ip_portSED/${redis_port}/g" \
       "${CONTAINERS_DIR}"/redis/redis-run.sh > "${temporary_dir}"/redis-run.sh  
  
echo 'redis-run.sh ready.'  
  
scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/redis \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${temporary_dir}"/redis-run.sh

get_user_password
user_pwd="${__RESULT}"

ssh_run_remote_command_as_root "chmod -R +x ${remote_dir}"/redis \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" 
    
ssh_run_remote_command_as_root "${remote_dir}/redis/redis-run.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Redis database successfully running.' ||
    {    
       echo 'WARN: changes made to IAM entities can take noticeable time for the information to be reflected globally.'
       echo 'Let''s wait a bit and check again (first time).' 
      
       wait 180  
      
       echo 'Let''s try now.' 
    
       ssh_run_remote_command_as_root "${remote_dir}/redis/redis-run.sh" \
          "${private_key_file}" \
          "${eip}" \
          "${ssh_port}" \
          "${user_nm}" \
          "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Redis database successfully running.' ||
          {
              echo 'ERROR: the problem persists after 3 minutes.'
              exit 1          
          }
    }
    
ssh_run_remote_command "rm -rf ${remote_dir:?}" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" 
    
#
# Permissions.
#

check_role_has_permission_policy_attached "${role_nm}" "${ECR_POLICY_NM}"
is_permission_policy_associated="${__RESULT}"

if [[ 'true' == "${is_permission_policy_associated}" ]]
then
   echo "Detatching permission policy from ${instance_key} role ..."
   
   detach_permission_policy_from_role "${role_nm}" "${ECR_POLICY_NM}"
      
   echo "Permission policy detached from ${instance_key} role."
else
   echo "WARN: permission policy already detached from ${instance_key} role."
fi 

## 
## Firewall
##

check_access_is_granted "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'true' == "${is_granted}" ]]
then
   revoke_access_from_cidr "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"  
   
   echo "Access revoked on ${ssh_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already revoked ${ssh_port} tcp 0.0.0.0/0."
fi

check_access_is_granted "${sgp_id}" "${redis_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${redis_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"  
   
   echo "Access granted on ${redis_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted on ${redis_port} tcp 0.0.0.0/0."
fi

# Removing old files
# shellcheck disable=SC2115
rm -rf  "${temporary_dir:?}"

echo "${instance_key} box Redis database provisioned."
echo "redis-cli -h ${eip} -p ${redis_port}"
echo

