#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

####
STEP 'AWS Redis db box'
####

echo 'Deleting AWS Redis db box ...'
echo

get_instance_id "${REDIS_INST_NM}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: AWS Redis db box not found.'
else
   get_instance_state "${REDIS_INST_NM}"
   instance_st="${__RESULT}"
   
   echo "* AWS Redis db box ID: ${instance_id} (${instance_st})."
fi

get_security_group_id "${REDIS_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: AWS Redis db security group not found.'
else
   echo "* AWS Redis db security group ID: ${sgp_id}."
fi

get_public_ip_address_associated_with_instance "${REDIS_INST_NM}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo '* WARN: AWS Redis db public IP address not found.'
else
   echo "* AWS Redis db public IP address: ${eip}."
fi

get_instance_profile_id "${REDIS_INST_PROFILE_NM}"
profile_id="${__RESULT}"

if [[ -z "${profile_id}" ]]
then
   echo '* WARN: AWS Redis db instance profile not found.'
else
   echo "* AWS Redis db instance profile ID: ${profile_id}."
fi

echo

##
## Instance profile.
##

check_instance_profile_exists "${REDIS_INST_PROFILE_NM}" > /dev/null
instance_profile_exists="${__RESULT}"

if [[ 'true' == "${instance_profile_exists}" ]]
then
   delete_instance_profile "${REDIS_INST_PROFILE_NM}"

   echo 'Redis db instance profile deleted.'
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
      echo "Deleting Redis db box ..."
      
      delete_instance "${instance_id}" 'and_wait' > /dev/null
      
      echo 'Redis db box deleted.'
   else
      echo 'Redis db box already deleted.'
   fi
fi

#
# Security group
# 
  
if [[ -n "${sgp_id}" ]]
then
   delete_security_group "${sgp_id}" 
      
   echo 'Redis db security group deleted.'
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

## Clearing
rm -rf "${TMP_DIR:?}"
mkdir -p "${TMP_DIR}"

echo 'Redis db box deleted.'
echo
