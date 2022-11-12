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
if [ "$#" -lt 2 ]; then
  echo "USAGE: instance_key network_key"
  echo "EXAMPLE: admin net"
  echo "Only provided $# arguments"
  exit 1
fi

instance_key="${1}"
network_key="${2}"
logfile_nm="${instance_key}".log

####
STEP "${instance_key} box"
####

get_datacenter 'Name'
dtc_nm="${__RESULT}"
ec2_get_datacenter_id "${dtc_nm}"
dtc_id="${__RESULT}"
  
if [[ -z "${dtc_id}" ]]
then
   echo '* ERROR: data center not found.'
   exit 1
else
   echo "* data center ID: ${dtc_id}."
fi

get_datacenter_network "${network_key}" 'Name' 
subnet_nm="${__RESULT}"
ec2_get_subnet_id "${subnet_nm}"
subnet_id="${__RESULT}"

if [[ -z "${subnet_id}" ]]
then
   echo '* ERROR: subnet not found.'
   exit 1
else
   echo "* subnet ID: ${subnet_id}."
fi

get_datacenter_instance "${instance_key}" 'ParentImageName'
image_nm="${__RESULT}"
ec2_get_image_id "${image_nm}"
image_id="${__RESULT}"

if [[ -z "${image_id}" ]]
then
   echo "* ERROR: image not found."
   exit 1
else
   echo "* image ID: ${image_id}."
fi

temporary_dir="${TMP_DIR}"/"${instance_key}"
rm -rf  "${temporary_dir:?}"
mkdir -p "${temporary_dir}"

echo

#
# Firewall
#

get_datacenter_instance "${instance_key}" 'SgpName'
sgp_nm="${__RESULT}"
ec2_get_security_group_id "${sgp_nm}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   ec2_create_security_group "${dtc_id}" "${sgp_nm}" "${sgp_nm}" >> "${LOGS_DIR}"/"${logfile_nm}" 
   ec2_get_security_group_id "${sgp_nm}"
   sgp_id="${__RESULT}"
   
   echo 'Security group created.'
else
   echo 'WARN: the security group is already created.'
fi

# Enable ping
ec2_check_access_is_granted "${sgp_id}" "-1" 'icmp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   ec2_allow_access_from_cidr "${sgp_id}" "-1" 'icmp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}" 
   
   echo 'Granted ICMP access.'
else
   echo 'WARN: ICMP access already granted.'
fi

#
# SSH key
#

get_datacenter_instance "${instance_key}" 'KeypairName'
keypair_nm="${__RESULT}"
ec2_check_aws_public_key_exists "${keypair_nm}" 
key_exists="${__RESULT}"

if [[ 'false' == "${key_exists}" ]]
then
   # Create a private key in the local 'access' directory.
   mkdir -p "${ACCESS_DIR}"
   ec2_generate_aws_keypair "${keypair_nm}" "${ACCESS_DIR}" 
   
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
get_datacenter_instance "${instance_key}" 'Hostname'
hostname="${__RESULT}" 
get_datacenter_instance "${instance_key}" 'UserName'
user_nm="${__RESULT}"
get_datacenter_instance "${instance_key}" 'UserPassword'
user_pwd="${__RESULT}"    

hashed_pwd="$(mkpasswd --method=SHA-512 --rounds=4096 "${user_pwd}")" 
awk -v key="${public_key}" -v pwd="${hashed_pwd}" -v user="${user_nm}" -v hostname="${hostname}" '{
    sub(/SEDuser_nameSED/,user)
    sub(/SEDhashed_passwordSED/,pwd)
    sub(/SEDpublic_keySED/,key)
    sub(/SEDhostnameSED/,hostname)
}1' "${PROJECT_DIR}"/amazon/box/config/cloud_init_template.yml > "${temporary_dir}"/cloud_init.yml
 
echo 'cloud_init.yml ready.' 

get_datacenter_instance "${instance_key}" 'Name'
instance_nm="${__RESULT}"
ec2_get_instance_id "${instance_nm}"
instance_id="${__RESULT}"

if [[ -n "${instance_id}" ]]
then
   ec2_get_instance_state "${instance_nm}"
   instance_st="${__RESULT}"
   
   if [[ -n "${instance_st}" ]]
   then
      echo "WARN: ${instance_key} box already created (${instance_st})."
      
      return 0
   fi
fi

echo "Creating ${instance_key} box ..."
   
get_datacenter_instance "${instance_key}" 'PrivateIP'
private_ip="${__RESULT}" 
get_datacenter 'Az'
az_nm="${__RESULT}"

ec2_run_instance \
    "${instance_nm}" \
    "${az_nm}" \
    "${sgp_id}" \
    "${subnet_id}" \
    "${private_ip}" \
    "${image_id}" \
    "${temporary_dir}"/cloud_init.yml
       
ec2_get_instance_id "${instance_nm}"
instance_id="${__RESULT}"    

echo "${instance_key} box created."

# Get the public IP address assigned to the instance. 
ec2_get_public_ip_address_associated_with_instance "${instance_nm}"
eip="${__RESULT}"

if [[ -n "${eip}" ]]
then
   echo "IP address ${eip}."
else
   echo 'WARN: IP address not found.'
fi

# Removing old files
# shellcheck disable=SC2115
rm -rf  "${temporary_dir:?}"
    
echo "${instance_key} box created."
echo

