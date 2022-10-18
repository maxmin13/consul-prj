#!/bin/bash

# shellcheck disable=SC2015

#####################################################
# Deletes an EC2 Linux EC2 box.
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

temporary_dir="${TMP_DIR}"/"${instance_key}"
rm -rf  "${temporary_dir:?}"
mkdir -p "${temporary_dir}"

echo

get_datacenter_instance "${instance_key}" 'Name'
instance_nm="${__RESULT}"
ec2_get_instance_id "${instance_nm}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo "* WARN: ${instance_key} box not found."
else
   ec2_get_instance_state "${instance_nm}"
   instance_st="${__RESULT}"
   
   echo "* ${instance_key} box ID: ${instance_id} (${instance_st})."
fi

get_datacenter_instance "${instance_key}" 'SgpName'
sgp_nm="${__RESULT}"
ec2_get_security_group_id "${sgp_nm}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo "* WARN: ${instance_key} security group not found."
else
   echo "* ${instance_key} security group ID: ${sgp_id}."
fi

ec2_get_public_ip_address_associated_with_instance "${instance_nm}"
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
   ec2_get_instance_state "${instance_nm}"
   instance_st="${__RESULT}"

   if [[ 'terminated' != "${instance_st}" ]]
   then
      echo "Deleting ${instance_key} box ..."
      
      ec2_delete_instance "${instance_id}" 'and_wait' >> "${LOGS_DIR}"/"${logfile_nm}" 2>&1 
      
      echo "${instance_key} box deleted."
   else
      echo "${instance_key} box already deleted."
   fi
fi

## 
## Firewall 
## 
  
if [[ -n "${sgp_id}" ]]
then  
   echo 'Deleting security group ...'

   ec2_delete_security_group_and_wait "${sgp_id}" >> "${LOGS_DIR}"/"${logfile_nm}" 2>&1 
   
   echo 'Security group deleted.'
fi

#
# Public IP
#

if [[ -n "${eip}" ]]
then
   ec2_get_allocation_id "${eip}"
   allocation_id="${__RESULT}" 
   
   if [[ -n "${allocation_id}" ]] 
   then
      ec2_release_public_ip_address "${allocation_id}"
   fi
   
   echo 'IP Address released from the account.'
fi

#
# SSH key
#

get_datacenter_instance "${instance_key}" 'KeypairName'
keypair_nm="${__RESULT}"
ec2_check_aws_public_key_exists "${keypair_nm}" 
key_exists="${__RESULT}"

if [[ 'true' == "${key_exists}" ]]
then
   ec2_delete_aws_keypair "${keypair_nm}" "${ACCESS_DIR}"
   
   echo 'SSH key deleted.'
fi

echo
echo "${instance_key} box deleted."
echo
