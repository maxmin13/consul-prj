#!/bin/bash

# shellcheck disable=SC2015

#####################################################
# Creates an EC2 Linux Sinatra box.
# Install a Sinatra server in a Docker container and
# runs it in the default Docker bridge network.
#####################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR=/home/"${USER_NM}"/script
SINATRA_ARCHIVE='webapp.zip'
SINATRA_DOCKER_CONTAINER_NETWORK_NM='bridge'

####
STEP 'Sinatra box'
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

get_image_id "${SHARED_IMG_NM}"
shared_image_id="${__RESULT}"

if [[ -z "${shared_image_id}" ]]
then
   echo '* ERROR: Shared image not found.'
   exit 1
else
   echo "* Shared image ID: ${shared_image_id}."
fi

# Removing old files
# shellcheck disable=SC2115
sinatra_tmp_dir="${TMP_DIR}"/sinatra
rm -rf  "${sinatra_tmp_dir:?}"
mkdir -p "${sinatra_tmp_dir}"

echo

#
# Firewall
#

get_security_group_id "${SINATRA_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -n "${sgp_id}" ]]
then
   echo 'WARN: the security group is already created.'
else
   create_security_group "${dtc_id}" "${SINATRA_INST_SEC_GRP_NM}" "${SINATRA_INST_SEC_GRP_NM}" >> "${LOGS_DIR}"/sinatra.log  
   get_security_group_id "${SINATRA_INST_SEC_GRP_NM}"
   sgp_id="${__RESULT}"
   
   echo 'Created security group.'
fi

# 
# Sinatra box
#

check_aws_public_key_exists "${SINATRA_INST_KEY_PAIR_NM}" 
key_exists="${__RESULT}"

if [[ 'false' == "${key_exists}" ]]
then
   # Create a private key in the local 'access' directory.
   mkdir -p "${ACCESS_DIR}"
   generate_aws_keypair "${SINATRA_INST_KEY_PAIR_NM}" "${ACCESS_DIR}" 
   
   echo 'SSH private key created.'
else
   echo 'WARN: SSH key-pair already created.'
fi

get_public_key "${SINATRA_INST_KEY_PAIR_NM}" "${ACCESS_DIR}"
public_key="${__RESULT}"
 
echo 'SSH public key extracted.'

## Removes the default user, creates the user 'awsadmin' and sets the instance's hostname.     

hashed_pwd="$(mkpasswd --method=SHA-512 --rounds=4096 "${USER_PWD}")" 
awk -v key="${public_key}" -v pwd="${hashed_pwd}" -v user="${USER_NM}" -v hostname="${SINATRA_INST_HOSTNAME}" '{
    sub(/SEDuser_nameSED/,user)
    sub(/SEDhashed_passwordSED/,pwd)
    sub(/SEDpublic_keySED/,key)
    sub(/SEDhostnameSED/,hostname)
}1' "${INSTANCE_DIR}"/sinatra/box/config/cloud_init_template.yml > "${sinatra_tmp_dir}"/cloud_init.yml
 
echo 'cloud_init.yml ready.' 

get_instance_id "${SINATRA_INST_NM}"
instance_id="${__RESULT}"

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${SINATRA_INST_NM}"
   instance_st="${__RESULT}"
   
   if [[ 'running' == "${instance_st}" || \
         'stopped' == "${instance_st}" || \
         'pending' == "${instance_st}" ]]
   then
      echo "WARN: box already created (${instance_st})."
   else
      echo "ERROR: box already created (${instance_st})."
      
      exit 1
   fi
else
   echo "Creating the box ..."

   run_instance \
       "${SINATRA_INST_NM}" \
       "${sgp_id}" \
       "${subnet_id}" \
       "${SINATRA_INST_PRIVATE_IP}" \
       "${shared_image_id}" \
       "${sinatra_tmp_dir}"/cloud_init.yml
       
   get_instance_id "${SINATRA_INST_NM}"
   instance_id="${__RESULT}"    

   echo "Box created."
fi

# Get the public IP address assigned to the instance. 
get_public_ip_address_associated_with_instance "${SINATRA_INST_NM}"
eip="${__RESULT}"

echo "Box public address ${eip}."

#
# Permissions.
#

# Applications that run on EC2 instances must sign their API requests with AWS credentials.
# For applications, AWS CLI, and Tools for Windows PowerShell commands that run on the instance, 
# you do not have to explicitly get the temporary security credentials, the AWS SDKs, AWS CLI, and 
# Tools for Windows PowerShell automatically get the credentials from the EC2 instance metadata 
# service and use them. 
# see: aws sts get-caller-identity

check_instance_profile_exists "${SINATRA_INST_PROFILE_NM}"
instance_profile_exists="${__RESULT}"

if [[ 'false' == "${instance_profile_exists}" ]]
then
   echo 'Creating instance profile ...'

   create_instance_profile "${SINATRA_INST_PROFILE_NM}" >> "${LOGS_DIR}"/sinatra.log

   echo 'Instance profile created.'
else
   echo 'WARN: instance profile already created.'
fi

get_instance_profile_id "${SINATRA_INST_PROFILE_NM}"
instance_profile_id="${__RESULT}"

check_instance_has_instance_profile_associated "${SINATRA_INST_NM}" "${instance_profile_id}"
is_profile_associated="${__RESULT}"

if [[ 'false' == "${is_profile_associated}" ]]
then
   echo 'Associating instance profile to the instance ...'

   associate_instance_profile_to_instance_and_wait "${SINATRA_INST_NM}" "${SINATRA_INST_PROFILE_NM}" >> "${LOGS_DIR}"/sinatra.log 2>&1  
   
   echo 'Instance profile associated to the instance.'
else
   echo 'WARN: instance profile already associated to the instance.'
fi

check_instance_profile_has_role_associated "${SINATRA_INST_PROFILE_NM}" "${SINATRA_AWS_ROLE_NM}" 
is_role_associated="${__RESULT}"

if [[ 'false' == "${is_role_associated}" ]]
then
   echo 'Associating role to instance profile ...'
   
   associate_role_to_instance_profile "${SINATRA_INST_PROFILE_NM}" "${SINATRA_AWS_ROLE_NM}"

   echo 'Role associated to the instance profile.' 
else
   echo 'WARN: role already associated to the instance profile.'
fi 

# Removing old files
# shellcheck disable=SC2115
rm -rf  "${sinatra_tmp_dir:?}"
    
echo 'Sinatra Box created.'
echo

