#!/bin/bash

# shellcheck disable=SC2015

#####################################################
# Deletes an EC2 Linux EC2 box.
#####################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

get_user_name
user_nm="${__RESULT}"
SCRIPTS_DIR=/home/"${user_nm}"/script

# Enforce parameter
if [ "$#" -lt 1 ]; then
  echo "USAGE: instance_nm"
  echo "EXAMPLE: admin"
  echo "Only provided $# arguments"
  exit 1
fi

instance_key="${1}"

####
STEP "${instance_key} box"
####

logfile_nm="${instance_key}".log

get_instance_name "${instance_key}"
instance_nm="${__RESULT}"
get_instance_id "${instance_nm}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo "* WARN: ${instance_key} box not found."
else
   get_instance_state "${instance_nm}"
   instance_st="${__RESULT}"
   
   echo "* ${instance_key} box ID: ${instance_id} (${instance_st})."
fi

get_security_group_name "${instance_key}"
sgp_nm="${__RESULT}"
get_security_group_id "${sgp_nm}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo "* WARN: ${instance_key} security group not found."
else
   echo "* ${instance_key} security group ID: ${sgp_id}."
fi

get_public_ip_address_associated_with_instance "${instance_nm}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo "* WARN: ${instance_key} box IP address not found."
else
   echo "* ${instance_key} box IP address: ${eip}."
fi

echo

#
# EC2 Box
#

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${instance_nm}"
   instance_st="${__RESULT}"

   if [[ 'terminated' != "${instance_st}" ]]
   then
      echo "Deleting ${instance_key} box ..."
      
      delete_instance "${instance_id}" 'and_wait' >> "${LOGS_DIR}"/${logfile_nm}
      
      echo "${instance_key} box deleted."
   else
      echo echo "${instance_key} box already deleted."
   fi
fi

## 
## Firewall 
## 
  
if [[ -n "${sgp_id}" ]]
then  
   echo "Deleting ${instance_key} security group ..."

   delete_security_group_and_wait "${sgp_id}" >> "${LOGS_DIR}"/${logfile_nm} 2>&1 
   
   echo "${instance_key} security group deleted."
fi

#
# Public IP
#

if [[ -n "${eip}" ]]
then
   get_allocation_id "${eip}"
   allocation_id="${__RESULT}" 
   
   if [[ -n "${allocation_id}" ]] 
   then
      release_public_ip_address "${allocation_id}"
   fi
   
   echo "${instance_key} IP Address released from the account." 
fi

#
# SSH key
#

get_keypair_name "${instance_key}"
keypair_nm="${__RESULT}"
check_aws_public_key_exists "${keypair_nm}" 
key_exists="${__RESULT}"

if [[ 'true' == "${key_exists}" ]]
then
   delete_aws_keypair "${keypair_nm}" "${ACCESS_DIR}"
   
   echo "${instance_key} SSH key deleted."
fi

echo
echo "${instance_key} box deleted."
echo
