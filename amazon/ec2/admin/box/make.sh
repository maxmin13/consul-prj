#!/bin/bash

# shellcheck disable=SC2015

#####################################################
# Creates an EC2 Linux jumpbox.
#####################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

####
STEP 'Admin box'
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
admin_tmp_dir="${TMP_DIR}"/admin
rm -rf  "${admin_tmp_dir:?}"
mkdir -p "${admin_tmp_dir}"

echo

#
# Firewall
#

get_security_group_id "${ADMIN_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -n "${sgp_id}" ]]
then
   echo 'WARN: security group is already created.'
else
   create_security_group "${dtc_id}" "${ADMIN_INST_SEC_GRP_NM}" "${ADMIN_INST_SEC_GRP_NM}" >> "${LOGS_DIR}"/admin.log
   get_security_group_id "${ADMIN_INST_SEC_GRP_NM}"
   sgp_id="${__RESULT}"
   
   echo 'Security group created.'
fi

# 
# Admin box
#

check_aws_public_key_exists "${ADMIN_INST_KEY_PAIR_NM}" 
key_exists="${__RESULT}"

if [[ 'false' == "${key_exists}" ]]
then
   # Create a private key in the local 'access' directory.
   mkdir -p "${ACCESS_DIR}"
   generate_aws_keypair "${ADMIN_INST_KEY_PAIR_NM}" "${ACCESS_DIR}" 
   
   echo 'SSH private key created.'
else
   echo 'WARN: SSH key-pair already created.'
fi

get_public_key "${ADMIN_INST_KEY_PAIR_NM}" "${ACCESS_DIR}"
public_key="${__RESULT}"
 
echo 'SSH public key extracted.'

## Removes the default user, creates the user 'awsadmin' and sets the instance's hostname.  

hashed_pwd="$(mkpasswd --method=SHA-512 --rounds=4096 "${USER_PWD}")" 
awk -v key="${public_key}" -v pwd="${hashed_pwd}" -v user="${USER_NM}" -v hostname="${ADMIN_INST_HOSTNAME}" '{
    sub(/SEDuser_nameSED/,user)
    sub(/SEDhashed_passwordSED/,pwd)
    sub(/SEDpublic_keySED/,key)
    sub(/SEDhostnameSED/,hostname)
}1' "${INSTANCE_DIR}"/admin/box/config/cloud_init_template.yml > "${admin_tmp_dir}"/cloud_init.yml
 
echo 'cloud_init.yml ready.' 

get_instance_id "${ADMIN_INST_NM}"
instance_id="${__RESULT}"

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${ADMIN_INST_NM}"
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
       "${ADMIN_INST_NM}" \
       "${sgp_id}" \
       "${subnet_id}" \
       "${ADMIN_INST_PRIVATE_IP}" \
       "${shared_image_id}" \
       "${admin_tmp_dir}"/cloud_init.yml
       
   get_instance_id "${ADMIN_INST_NM}"
   instance_id="${__RESULT}"    

   echo "Box created."
fi

# Get the public IP address assigned to the instance. 
get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}"
eip="${__RESULT}"

echo "Admin IP address ${eip}."

#
# Permissions.
#

# Applications that run on EC2 instances must sign their API requests with AWS credentials.
# For applications, AWS CLI, and Tools for Windows PowerShell commands that run on the instance, 
# you do not have to explicitly get the temporary security credentials, the AWS SDKs, AWS CLI, and 
# Tools for Windows PowerShell automatically get the credentials from the EC2 instance metadata 
# service and use them. 
# see: aws sts get-caller-identity

check_instance_profile_exists "${ADMIN_INST_PROFILE_NM}"
instance_profile_exists="${__RESULT}"

if [[ 'false' == "${instance_profile_exists}" ]]
then
   echo 'Creating instance profile ...'

   create_instance_profile "${ADMIN_INST_PROFILE_NM}" >> "${LOGS_DIR}"/admin.log 

   echo 'Instance profile created.'
else
   echo 'WARN: instance profile already created.'
fi

get_instance_profile_id "${ADMIN_INST_PROFILE_NM}"
instance_profile_id="${__RESULT}"

check_instance_has_instance_profile_associated "${ADMIN_INST_NM}" "${instance_profile_id}"
is_profile_associated="${__RESULT}"

if [[ 'false' == "${is_profile_associated}" ]]
then
   echo 'Associating instance profile to the instance ...'
   
   associate_instance_profile_to_instance_and_wait "${ADMIN_INST_NM}" "${ADMIN_INST_PROFILE_NM}" >> "${LOGS_DIR}"/admin.log 2>&1
   
   echo 'Instance profile associated to the instance.'
else
   echo 'WARN: instance profile already associated to the instance.'
fi

check_instance_profile_has_role_associated "${ADMIN_INST_PROFILE_NM}" "${ADMIN_AWS_ROLE_NM}" 
is_role_associated="${__RESULT}"

if [[ 'false' == "${is_role_associated}" ]]
then
   echo 'Associating role to instance profile ...'
   
   associate_role_to_instance_profile "${ADMIN_INST_PROFILE_NM}" "${ADMIN_AWS_ROLE_NM}"
      
   echo 'Role associated to the instance profile.' 
else
   echo 'WARN: role already associated to the instance profile.'
fi 


# Removing old files
# shellcheck disable=SC2115
rm -rf  "${admin_tmp_dir:?}"

echo 'Admin box created.'       
echo

