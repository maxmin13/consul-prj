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
STEP 'AWS shared box'
#

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
rm -rf "${TMP_DIR:?}"/"${shared_dir}"
mkdir "${TMP_DIR}"/"${shared_dir}"

## 
## Security group
##

get_security_group_id "${SHARED_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -n "${sgp_id}" ]]
then
   echo 'WARN: the Shared security group is already created.'
else
   create_security_group "${dtc_id}" "${SHARED_INST_SEC_GRP_NM}" 'Shared security group.'
   get_security_group_id "${SHARED_INST_SEC_GRP_NM}"
   sgp_id="${__RESULT}"

   echo 'Created Shared security group.'
fi

set +e
allow_access_from_cidr "${sgp_id}" '22' 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e
   
echo 'Granted SSH access on port 22.'

set +e
allow_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e
   
echo "Granted SSH access on port ${SHARED_INST_SSH_PORT}."

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
}1' "${INSTANCE_DIR}"/shared/config/cloud_init_template.yml > "${TMP_DIR}"/"${shared_dir}"/cloud_init.yml
  
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
       "${TMP_DIR}"/"${shared_dir}"/cloud_init.yml
       
   get_instance_id "${SHARED_INST_NM}"
   instance_id="${__RESULT}"   

   echo "Shared box created."
fi  
       
get_public_ip_address_associated_with_instance "${SHARED_INST_NM}"
eip="${__RESULT}"

echo "Shared box public address: ${eip}."

# Verify it the SSH port is still 22 or it has changed.
private_key_file="${ACCESS_DIR}"/"${SHARED_INST_KEY_PAIR_NM}"

get_ssh_port "${private_key_file}" "${eip}" "${USER_NM}" '22' "${SHARED_INST_SSH_PORT}" 
ssh_port="${__RESULT}"

echo "The SSH port on the Shared box is ${ssh_port}."

##
## Upload the scripts to the instance
## 

echo
echo 'Uploading the scripts to the Shared box ...'

remote_dir=/home/"${USER_NM}"/script

ssh_run_remote_command "rm -rf ${remote_dir} && mkdir ${remote_dir}" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${USER_NM}"                     
   
sed -e "s/SEDssh_portSED/${SHARED_INST_SSH_PORT}/g" \
    -e "s/AllowUsers/#AllowUsers/g" \
       "${PROVISION_DIR}"/security/sshd_config_template > "${TMP_DIR}"/"${shared_dir}"/sshd_config
       
echo 'sshd_config ready.' 

sed -e "s/SEDuser_nmSED/${USER_NM}/g" \
    -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}")/g" \
       "${PROVISION_DIR}"/docker/docker.sh > "${TMP_DIR}"/docker.sh    
       
echo 'docker.sh ready.'     

scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${USER_NM}" "${remote_dir}" \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${PROVISION_DIR}"/security/secure-linux.sh \
    "${PROVISION_DIR}"/security/check-linux.sh \
    "${PROVISION_DIR}"/yumupdate.sh \
    "${TMP_DIR}"/docker.sh \
    "${TMP_DIR}"/"${shared_dir}"/sshd_config        

ssh_run_remote_command_as_root "chmod +x ${remote_dir}/*.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${USER_NM}" \
    "${USER_PWD}"

echo 'Securing the Shared box ...'
                
set +e

# Harden the kernel, change SSH port to 38142, set ec2-user password and sudo with password.
ssh_run_remote_command_as_root "${remote_dir}/secure-linux.sh" \
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
   echo 'Shared box successfully secured.'

   set +e
   ssh_run_remote_command_as_root "reboot" \
       "${private_key_file}" \
       "${eip}" \
       "${ssh_port}" \
       "${USER_NM}" \
       "${USER_PWD}"
   set -e
else
   echo 'ERROR: securing the Shared box.'
   exit 1
fi

# Finally, remove access from SSH port 22.
set +e
revoke_access_from_cidr "${sgp_id}" '22' 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e

echo 'Revoked SSH access to the Shared box port 22.'

wait_ssh_started "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}"

get_ssh_port "${private_key_file}" "${eip}" "${USER_NM}" '22' "${SHARED_INST_SSH_PORT}" 
ssh_port="${__RESULT}"

echo "The SSH port on the Shared box is ${ssh_port}." 
echo 'Running security checks in the Shared box ...'

ssh_run_remote_command_as_root "${remote_dir}/check-linux.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}"  
    
echo 'Provisioning Docker ...'

set +e                                
ssh_run_remote_command_as_root "${remote_dir}/docker.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}"   
                            
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
ssh_run_remote_command "rm -rf ${remote_dir:?}" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}"    
    
# After the instance is created, stop it before creating the image, to ensure data integrity.

stop_instance "${instance_id}" > /dev/null  

echo 'Shared box stopped.'   

## 
## SSH Access
## 

# Revoke SSH access from the development machine.
set +e
revoke_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e
   
echo 'Revoked SSH access to the Shared box.'

# Removing old files
rm -rf "${TMP_DIR:?}"/"${shared_dir}"

