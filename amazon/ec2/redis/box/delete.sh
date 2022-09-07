#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

####
STEP 'Redis box'
####

echo 'Deleting Redis box ...'
echo

get_instance_id "${REDIS_INST_NM}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: Redis box not found.'
else
   get_instance_state "${REDIS_INST_NM}"
   instance_st="${__RESULT}"
   
   echo "* Redis box ID: ${instance_id} (${instance_st})."
fi

get_security_group_id "${REDIS_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: security group not found.'
else
   echo "* security group ID: ${sgp_id}."
fi

get_public_ip_address_associated_with_instance "${REDIS_INST_NM}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo '* WARN: Redis IP address not found.'
else
   echo "* Redis IP address: ${eip}."
fi

get_instance_profile_id "${REDIS_INST_PROFILE_NM}"
profile_id="${__RESULT}"

if [[ -z "${profile_id}" ]]
then
   echo '* WARN: instance profile not found.'
else
   echo "* instance profile ID: ${profile_id}."
fi

echo

##
## Permissions.
##

check_instance_profile_exists "${REDIS_INST_PROFILE_NM}" >> "${LOGS_DIR}"/redis.log
instance_profile_exists="${__RESULT}"

if [[ 'true' == "${instance_profile_exists}" ]]
then
   delete_instance_profile "${REDIS_INST_PROFILE_NM}" >> "${LOGS_DIR}"/redis.log

   echo 'Instance profile deleted.'
fi

#
# Redis box
#

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${REDIS_INST_NM}"
   instance_st="${__RESULT}"

   if [[ 'terminated' != "${instance_st}" ]]
   then
      echo "Deleting box ..."
      
      delete_instance "${instance_id}" 'and_wait' >> "${LOGS_DIR}"/redis.log
      
      echo 'Box deleted.'
   else
      echo 'Box already deleted.'
   fi
fi

## 
## Firewall 
## 
  
if [[ -n "${sgp_id}" ]]
then  
   echo 'Deleting security group ...'

   delete_security_group_and_wait "${sgp_id}" >> "${LOGS_DIR}"/admin.log 2>&1 
   
   echo "Security group deleted."
fi

if [[ -n "${eip}" ]]
then
   get_allocation_id "${eip}"
   allocation_id="${__RESULT}" 
   
   if [[ -n "${allocation_id}" ]] 
   then
      release_public_ip_address "${allocation_id}"
   fi
   
   echo "Address released from the account." 
fi

check_aws_public_key_exists "${REDIS_INST_KEY_PAIR_NM}" 
key_exists="${__RESULT}"

if [[ 'true' == "${key_exists}" ]]
then
   delete_aws_keypair "${REDIS_INST_KEY_PAIR_NM}" "${ACCESS_DIR}"
   
   echo 'The SSH access key-pair have been deleted.'
fi

echo 'Redis box deleted.'
echo
