#!/bin/bash

# shellcheck disable=SC2015

#####################################################
# Creates an EC2 Linux EC2 box that inherits from 
# the Shared image.
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

####
STEP "${instance_key} box"
####

logfile_nm="${instance_key}".log

get_datacenter_name
dtc_nm="${__RESULT}"
get_datacenter_id "${dtc_nm}"
dtc_id="${__RESULT}"
  
if [[ -z "${dtc_id}" ]]
then
   echo '* ERROR: data center not found.'
   exit 1
else
   echo "* data center ID: ${dtc_id}."
fi

get_subnet_name
subnet_nm="${__RESULT}"
get_subnet_id "${subnet_nm}"
subnet_id="${__RESULT}"

if [[ -z "${subnet_id}" ]]
then
   echo '* ERROR: main subnet not found.'
   exit 1
else
   echo "* main subnet ID: ${subnet_id}."
fi

get_parent_image_name "${instance_key}"
parent_image_nm="${__RESULT}"
get_image_id "${parent_image_nm}"
parent_image_id="${__RESULT}"

if [[ -z "${parent_image_id}" ]]
then
   echo "* ERROR: parent image not found."
   exit 1
else
   echo "* parent image ID: ${parent_image_id}."
fi

temporary_dir="${TMP_DIR}"/"${instance_key}"
rm -rf  "${temporary_dir:?}"
mkdir -p "${temporary_dir}"

echo

#
# Firewall
#

get_security_group_name "${instance_key}"
sgp_nm="${__RESULT}"
get_security_group_id "${sgp_nm}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   create_security_group "${dtc_id}" "${sgp_nm}" "${sgp_nm}" >> "${LOGS_DIR}"/"${logfile_nm}" 
   get_security_group_id "${sgp_nm}"
   sgp_id="${__RESULT}"
   
   echo 'Security group created.'
else
   echo 'WARN: the security group is already created.'
fi

#
# SSH key
#

get_keypair_name "${instance_key}"
keypair_nm="${__RESULT}"
check_aws_public_key_exists "${keypair_nm}" 
key_exists="${__RESULT}"

if [[ 'false' == "${key_exists}" ]]
then
   # Create a private key in the local 'access' directory.
   mkdir -p "${ACCESS_DIR}"
   generate_aws_keypair "${keypair_nm}" "${ACCESS_DIR}" 
   
   echo 'SSH key created.'
else
   echo 'WARN: SSH key-pair already created.'
fi

#
# EC2 Box
#

get_public_key "${keypair_nm}" "${ACCESS_DIR}"
public_key="${__RESULT}"

## Removes the default user, creates the user 'awsadmin' and sets the instance's hostname. 
get_hostname "${instance_key}"
hostname="${__RESULT}" 
get_user_name
user_nm="${__RESULT}"
get_user_password
user_pwd="${__RESULT}"    

hashed_pwd="$(mkpasswd --method=SHA-512 --rounds=4096 "${user_pwd}")" 
awk -v key="${public_key}" -v pwd="${hashed_pwd}" -v user="${user_nm}" -v hostname="${hostname}" '{
    sub(/SEDuser_nameSED/,user)
    sub(/SEDhashed_passwordSED/,pwd)
    sub(/SEDpublic_keySED/,key)
    sub(/SEDhostnameSED/,hostname)
}1' "${PROJECT_DIR}"/amazon/box/config/cloud_init_template.yml > "${temporary_dir}"/cloud_init.yml
 
echo 'cloud_init.yml ready.' 

get_instance_name "${instance_key}"
instance_nm="${__RESULT}"
get_instance_id "${instance_nm}"
instance_id="${__RESULT}"

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${instance_nm}"
   instance_st="${__RESULT}"
   
   if [[ -n "${instance_st}" ]]
   then
      echo "WARN: ${instance_key} box already created (${instance_st})."
      
      return 0
   fi
fi

echo "Creating ${instance_key} box ..."
   
get_private_ip "${instance_key}"
private_ip="${__RESULT}" 
get_availability_zone_name
az_nm="${__RESULT}"

run_instance \
    "${instance_nm}" \
    "${az_nm}" \
    "${sgp_id}" \
    "${subnet_id}" \
    "${private_ip}" \
    "${parent_image_id}" \
    "${temporary_dir}"/cloud_init.yml
       
get_instance_id "${instance_nm}"
instance_id="${__RESULT}"    

echo "${instance_key} box created."

# Get the public IP address assigned to the instance. 
get_public_ip_address_associated_with_instance "${instance_nm}"
eip="${__RESULT}"

if [[ -n "${eip}" ]]
then
   echo "${instance_key} box public address ${eip}."
else
   echo "WARN: ${instance_key} box public address not found."
fi

# Removing old files
# shellcheck disable=SC2115
rm -rf  "${temporary_dir:?}"
    
echo "${instance_key} box created."
echo

