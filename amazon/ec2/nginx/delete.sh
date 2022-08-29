#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

####
STEP 'Nginx box'
####

echo 'Deleting Nginx box ...'
echo

get_instance_id "${NGINX_INST_NM}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: Nginx box not found.'
else
   get_instance_state "${NGINX_INST_NM}"
   instance_st="${__RESULT}"
   
   echo "* Nginx box ID: ${instance_id} (${instance_st})."
fi

get_security_group_id "${NGINX_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: security group not found.'
else
   echo "* security group ID: ${sgp_id}."
fi

get_public_ip_address_associated_with_instance "${NGINX_INST_NM}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo '* WARN: public IP address not found.'
else
   echo "* public IP address: ${eip}."
fi

get_instance_profile_id "${NGINX_INST_PROFILE_NM}"
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

check_instance_profile_exists "${NGINX_INST_PROFILE_NM}" > /dev/null
instance_profile_exists="${__RESULT}"

if [[ 'true' == "${instance_profile_exists}" ]]
then
   delete_instance_profile "${NGINX_INST_PROFILE_NM}"

   echo 'Instance profile deleted.'
fi

#
# Nginx box
#

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${NGINX_INST_NM}"
   instance_st="${__RESULT}"

   if [[ 'terminated' != "${instance_st}" ]]
   then
      echo "Deleting Nginx box ..."
      
      delete_instance "${instance_id}" 'and_wait' > /dev/null
      
      echo 'Nginx box deleted.'
   else
      echo 'Nginx box already deleted.'
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

check_aws_public_key_exists "${NGINX_INST_KEY_PAIR_NM}" 
key_exists="${__RESULT}"

if [[ 'true' == "${key_exists}" ]]
then
   delete_aws_keypair "${NGINX_INST_KEY_PAIR_NM}" "${ACCESS_DIR}"
   
   echo 'The SSH access key-pair have been deleted.'
fi

## Clearing
rm -rf "${TMP_DIR:?}"
mkdir -p "${TMP_DIR}"

echo 'Nginx box deleted.'
echo
