#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#
STEP 'AWS Shared box'
#

shared_dir='shared'

# The temporary box used to build the image may already be gone
get_instance_id "${SHARED_INST_NM}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: Shared box not found.'
else
   get_instance_state "${SHARED_INST_NM}"
   instance_st="${__RESULT}"
   
   echo "* Shared box ID: ${instance_id} (${instance_st})."
fi

# The temporary security group used to build the image may already be gone
get_security_group_id "${SHARED_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: security group not found.'
else
   echo "* security group. ${sgp_id}."
fi

echo

## 
## Shared box.
## 

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${SHARED_INST_NM}"
   instance_st="${__RESULT}"
   
   if [[ 'terminated' != "${instance_st}" ]]
   then
      echo 'Deleting Shared box ...' 
      
      delete_instance "${instance_id}" > /dev/null
      
      echo 'Shared box deleted.'
   fi
fi

## 
## Firewall 
## 
  
if [[ -n "${sgp_id}" ]]
then  
   echo 'Deleting security group ...'

   # shellcheck disable=SC2015
   delete_security_group "${sgp_id}" > /dev/null 2>&1 && echo 'Security group deleted.' || 
   {
      wait 60
      delete_security_group "${sgp_id}" > /dev/null 2>&1 && echo 'Security group deleted.' || 
      {
         wait 60
         delete_security_group "${sgp_id}" > /dev/null 2>&1 echo 'Security group deleted.' || 
         {
            echo 'ERROR: deleting security group.'
            exit 1
         }         
      } 
   }   
fi

## 
## Public IP 
## 

get_public_ip_address_associated_with_instance "${SHARED_INST_NM}"
eip="${__RESULT}"

if [[ -n "${eip}" ]]
then
   get_allocation_id "${eip}"
   allocation_id="${__RESULT}"
   
   if [[ -n "${allocation_id}" ]] 
   then
      release_public_ip_address "${allocation_id}"
   fi
   
   echo 'Address released from the account.' 
fi

##
## SSH keys.
##

check_aws_public_key_exists "${SHARED_INST_KEY_PAIR_NM}" 
key_exists="${__RESULT}"

if [[ 'true' == "${key_exists}" ]]
then
   delete_aws_keypair "${SHARED_INST_KEY_PAIR_NM}" "${ACCESS_DIR}"
   
   echo 'The SSH access key-pair have been deleted.'
fi

echo

rm -rf "${TMP_DIR:?}"/"${shared_dir}"

