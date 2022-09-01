#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

####
STEP 'Admin box'
####

CONSUL_SECRET_NM='consulkey'

echo 'Deleting box ...'
echo

get_instance_id "${ADMIN_INST_NM}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: box not found.'
else
   get_instance_state "${ADMIN_INST_NM}"
   instance_st="${__RESULT}"
   
   echo "* box ID: ${instance_id} (${instance_st})."
fi

get_security_group_id "${ADMIN_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: security group not found.'
else
   echo "* security group ID: ${sgp_id}."
fi

get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo '* WARN: public IP address not found.'
else
   echo "* public IP address: ${eip}."
fi

get_instance_profile_id "${ADMIN_INST_PROFILE_NM}"
profile_id="${__RESULT}"

if [[ -z "${profile_id}" ]]
then
   echo '* WARN: instance profile not found.'
else
   echo "* instance profile ID: ${profile_id}."
fi

echo

##
## Permissions
##

check_instance_profile_exists "${ADMIN_INST_PROFILE_NM}" | logto admin.log
instance_profile_exists="${__RESULT}"

if [[ 'true' == "${instance_profile_exists}" ]]
then
   delete_instance_profile "${ADMIN_INST_PROFILE_NM}"

   echo 'Instance profile deleted.'
fi

#
# Admin box
#

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${ADMIN_INST_NM}"
   instance_st="${__RESULT}"

   if [[ 'terminated' != "${instance_st}" ]]
   then
      echo "Deleting box ..."
      
      delete_instance "${instance_id}" 'and_wait' | logto admin.log
      
      echo 'Box deleted.'
   else
      echo 'Box already deleted.'
   fi
fi

#
# Firewall
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
   
   echo "IP address released from the account." 
fi

check_aws_public_key_exists "${ADMIN_INST_KEY_PAIR_NM}" 
key_exists="${__RESULT}"

if [[ 'true' == "${key_exists}" ]]
then
   delete_aws_keypair "${ADMIN_INST_KEY_PAIR_NM}" "${ACCESS_DIR}"
   
   echo 'The SSH access key-pair have been deleted.'
fi

## Clearing
rm -rf "${TMP_DIR:?}"
mkdir -p "${TMP_DIR}"

echo 'Box deleted.'
echo
