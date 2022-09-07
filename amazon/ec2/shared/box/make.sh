#!/usr/bin/bash

#####################################################
# Creates an EC2 Linux Shared box.
#####################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#
STEP 'Shared box'
#

SCRIPTS_DIR=/home/"${USER_NM}"/script

get_datacenter_id "${DTC_NM}"
dtc_id="${__RESULT}"
  
if [[ -z "${dtc_id}" ]]
then
   echo '* ERROR: data center not found.'
   exit 1
else
   echo "* data center ID: ${dtc_id}."
fi

get_subnet_id "${DTC_SUBNET_MAIN_NM}"
subnet_id="${__RESULT}"

if [[ -z "${subnet_id}" ]]
then
   echo '* ERROR: main subnet not found.'
   exit 1
else
   echo "* main subnet ID: ${subnet_id}."
fi

get_image_id "${SHARED_IMG_NM}"
image_id="${__RESULT}"
image_st=''

if [[ -z "${image_id}" ]]
then
   echo '* WARN: Shared image not found.'
else
   get_image_state "${SHARED_IMG_NM}"
   image_st="${__RESULT}"
   
   echo "* Shared image ID: ${image_id} (${image_st})."
fi

echo

# Removing old files
# shellcheck disable=SC2115
shared_tmp_dir="${TMP_DIR}"/shared
rm -rf  "${shared_tmp_dir:?}"
mkdir -p "${shared_tmp_dir}"

## 
## Firewall
##

get_security_group_id "${SHARED_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -n "${sgp_id}" ]]
then
   echo 'WARN: the security group is already created.'
else
   create_security_group "${dtc_id}" "${SHARED_INST_SEC_GRP_NM}" 'Shared security group.' >> "${LOGS_DIR}"/shared.log
   get_security_group_id "${SHARED_INST_SEC_GRP_NM}"
   sgp_id="${__RESULT}"

   echo 'Created security group.'
fi

##
## SSH keys.
##

check_aws_public_key_exists "${SHARED_INST_KEY_PAIR_NM}" 
key_exists="${__RESULT}"

if [[ 'false' == "${key_exists}" ]]
then
   # Create a private key in the local 'access' directory.
   mkdir -p "${ACCESS_DIR}"
   generate_aws_keypair "${SHARED_INST_KEY_PAIR_NM}" "${ACCESS_DIR}" 
   
   echo 'SSH private key created.'
else
   echo 'WARN: SSH key-pair already created.'
fi

get_public_key "${SHARED_INST_KEY_PAIR_NM}" "${ACCESS_DIR}"
public_key="${__RESULT}"
   
echo 'SSH public key extracted.'

##
## Cloud init
##   

## Removes the default user, creates the admin-user user and sets the instance's hostname.     

hashed_pwd="$(mkpasswd --method=SHA-512 --rounds=4096 "${USER_PWD}")" 

awk -v key="${public_key}" -v pwd="${hashed_pwd}" -v user="${USER_NM}" -v hostname="${SHARED_INST_HOSTNAME}" '{
    sub(/SEDuser_nameSED/,user)
    sub(/SEDhashed_passwordSED/,pwd)
    sub(/SEDpublic_keySED/,key)
    sub(/SEDhostnameSED/,hostname)
}1' "${INSTANCE_DIR}"/shared/box/config/cloud_init_template.yml > "${shared_tmp_dir}"/cloud_init.yml
  
echo 'cloud_init.yml ready.'  

## 
## Shared box
## 

get_instance_id "${SHARED_INST_NM}"
instance_id="${__RESULT}"

if [[ -n "${image_id}" && 'available' == "${image_st}" ]]
then    
   echo 'Shared image already created, skipping creating Shared box.'
   echo
   return 0
   
elif [[ -n "${instance_id}" ]]
then
   get_instance_state "${SHARED_INST_NM}"
   instance_st="${__RESULT}"

   if [[ 'running' == "${instance_st}" ]]
   then
      echo "WARN: Shared box already created (${instance_st})."
      echo
   else
      # An istance lasts in terminated status for about an hour, before that change name.
      echo "ERROR: Shared box already created (${instance_st})."
      exit 1
   fi
else
   echo 'Creating the Shared box ...'
   
   run_instance \
       "${SHARED_INST_NM}" \
       "${sgp_id}" \
       "${subnet_id}" \
       "${SHARED_INST_PRIVATE_IP}" \
       "${AWS_BASE_IMG_ID}" \
       "${shared_tmp_dir}"/cloud_init.yml
       
   get_instance_id "${SHARED_INST_NM}"
   instance_id="${__RESULT}"   

   echo "Shared box created."
fi  
       
get_public_ip_address_associated_with_instance "${SHARED_INST_NM}"
eip="${__RESULT}"

echo "Public address ${eip}."

# Removing old files
rm -rf "${shared_tmp_dir:?}"

echo 'Shared box created.'
echo

