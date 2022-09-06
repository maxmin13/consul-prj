#!/usr/bin/bash

##########################################
# makes a secure linux box image:
# hardened, ssh on 38142.
# No root access to the instance.
# Remove the ec2-user default user and 
# creates the shared-user user.
# Install Docker.
##########################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#
STEP 'Shared box'
#

SCRIPTS_DIR=/home/"${USER_NM}"/script
shared_dir='shared'

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
shared_tmp_dir="${TMP_DIR}"/sinatra
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

check_access_is_granted "${sgp_id}" '22' 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" '22' 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/shared.log 
   
   echo "Access granted on 22 tcp 0.0.0.0/0."
else
   echo "WARN: access already granted on 22 tcp 0.0.0.0/0."
fi
   
check_access_is_granted "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/shared.log 
   
    echo "Access granted on "${SHARED_INST_SSH_PORT}" tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${SHARED_INST_SSH_PORT} tcp 0.0.0.0/0."
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
}1' "${INSTANCE_DIR}"/shared/config/cloud_init_template.yml > "${shared_tmp_dir}"/cloud_init.yml
  
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

# Verify it the SSH port is still 22 or it has changed.
private_key_file="${ACCESS_DIR}"/"${SHARED_INST_KEY_PAIR_NM}"

get_ssh_port "${private_key_file}" "${eip}" "${USER_NM}" '22' "${SHARED_INST_SSH_PORT}" 
ssh_port="${__RESULT}"

echo "SSH port ${ssh_port}."

##
## Upload the scripts to the instance
## 

echo
echo 'Uploading the scripts to the box ...'

ssh_run_remote_command "rm -rf ${SCRIPTS_DIR:?} && mkdir ${SCRIPTS_DIR}"/shared \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${USER_NM}"                     
   
sed -e "s/SEDssh_portSED/${SHARED_INST_SSH_PORT}/g" \
    -e "s/AllowUsers/#AllowUsers/g" \
       "${PROVISION_DIR}"/security/sshd_config_template > "${shared_tmp_dir}"/sshd_config
       
echo 'sshd_config ready.' 

sed -e "s/SEDuser_nmSED/${USER_NM}/g" \
    -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}")/g" \
       "${PROVISION_DIR}"/docker/docker.sh > "${shared_tmp_dir}"/docker.sh    
       
echo 'docker.sh ready.'     

scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${USER_NM}" "${SCRIPTS_DIR}"/shared \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${PROVISION_DIR}"/security/secure-linux.sh \
    "${PROVISION_DIR}"/security/check-linux.sh \
    "${PROVISION_DIR}"/yumupdate.sh \
    "${shared_tmp_dir}"/docker.sh \
    "${shared_tmp_dir}"/"${shared_dir}"/sshd_config        

ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR}"/shared \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" 

echo 'Securing the box ...'
                
set +e
# Harden the kernel, change SSH port to 38142, set ec2-user password and sudo with password.
ssh_run_remote_command_as_root "${SCRIPTS_DIR}"/shared/secure-linux.sh \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${USER_NM}" \
    "${USER_PWD}"
                   
exit_code=$?
set -e

# shellcheck disable=SC2181
if [ 194 -eq "${exit_code}" ]
then
   echo 'Box successfully secured.'

   set +e
   ssh_run_remote_command_as_root "reboot" \
       "${private_key_file}" \
       "${eip}" \
       "${ssh_port}" \
       "${USER_NM}" \
       "${USER_PWD}"
   set -e
else
   echo 'ERROR: securing the box.'
   exit 1
fi

#
# Firewall
#

check_access_is_granted "${sgp_id}" '22' 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'true' == "${is_granted}" ]]
then
   revoke_access_from_cidr "${sgp_id}" '22' 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/shared.log  
   
   echo "Access revoked on 22 tcp 0.0.0.0/0."
else
   echo "WARN: access already revoked on 22 tcp 0.0.0.0/0."
fi

wait_ssh_started "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}"

get_ssh_port "${private_key_file}" "${eip}" "${USER_NM}" '22' "${SHARED_INST_SSH_PORT}" 
ssh_port="${__RESULT}"

echo "SSH port ${ssh_port}."
echo 'Running security checks ...'

ssh_run_remote_command_as_root "${SCRIPTS_DIR}"/shared/check-linux.sh \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" >> "${LOGS_DIR}"/shared.log    
    
echo 'Provisioning Docker ...'

set +e                                
ssh_run_remote_command_as_root "${SCRIPTS_DIR}"/shared/docker.sh \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" >> "${LOGS_DIR}"/shared.log   
                            
exit_code=$?
set -e

# shellcheck disable=SC2181
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'Docker successfully installed.'     
else
   echo 'ERROR: installing Docker.'
   exit 1
fi     
   
# Clear remote directory.
ssh_run_remote_command "rm -rf ${SCRIPTS_DIR:?}" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}"    
    
# After the instance is created, stop it before creating the image, to ensure data integrity.

stop_instance "${instance_id}" >> "${LOGS_DIR}"/shared.log

echo 'Box stopped.'   

## 
## Firewall
## 

check_access_is_granted "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'true' == "${is_granted}" ]]
then
   revoke_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/shared.log  
   
   echo "Access revoked on ${SHARED_INST_SSH_PORT} tcp 0.0.0.0/0."
else
   echo "WARN: access already revoked on ${SHARED_INST_SSH_PORT} tcp 0.0.0.0/0."
fi

# Removing old files
rm -rf "${shared_tmp_dir:?}"

echo 'Shared box created.'
echo

