#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

####
STEP 'Sinatra box'
####

echo 'Deleting Sinatra box ...'
echo

get_instance_id "${SINATRA_INST_NM}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: Sinatra box not found.'
else
   get_instance_state "${SINATRA_INST_NM}"
   instance_st="${__RESULT}"
   
   echo "* Sinatra box ID: ${instance_id} (${instance_st})."
fi

get_security_group_id "${SINATRA_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: security group not found.'
else
   echo "* Security group ID: ${sgp_id}."
fi

get_public_ip_address_associated_with_instance "${SINATRA_INST_NM}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo '* WARN: public IP address not found.'
else
   echo "* public IP address: ${eip}."
fi

get_instance_profile_id "${SINATRA_INST_PROFILE_NM}"
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

check_instance_profile_exists "${SINATRA_INST_PROFILE_NM}" > /dev/null
instance_profile_exists="${__RESULT}"

if [[ 'true' == "${instance_profile_exists}" ]]
then
   delete_instance_profile "${SINATRA_INST_PROFILE_NM}"

   echo 'Instance profile deleted.'
fi

#
# Sinatra box
#

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${SINATRA_INST_NM}"
   instance_st="${__RESULT}"

   if [[ 'terminated' != "${instance_st}" ]]
   then
      echo "Deleting Sinatra box ..."
      
      delete_instance "${instance_id}" 'and_wait' > /dev/null
      
      echo 'Sinatra box deleted.'
   else
      echo 'Sinatra box already deleted.'
   fi
fi

#
# Security group
# 
  
if [[ -n "${sgp_id}" ]]
then
   delete_security_group "${sgp_id}" 
      
   echo 'Security group deleted.'
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

check_aws_public_key_exists "${SINATRA_INST_KEY_PAIR_NM}" 
key_exists="${__RESULT}"

if [[ 'true' == "${key_exists}" ]]
then
   delete_aws_keypair "${SINATRA_INST_KEY_PAIR_NM}" "${ACCESS_DIR}"
   
   echo 'The SSH access key-pair have been deleted.'
fi

## Clearing
rm -rf "${TMP_DIR:?}"
mkdir -p "${TMP_DIR}"

echo 'Sinatra box deleted.'
echo
