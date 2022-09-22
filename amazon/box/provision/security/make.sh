#!/usr/bin/bash

# shellcheck disable=SC2153

####################################################################################
# makes a secure linux box:
# hardened, ssh on 38142
# No root access to the instance
# Remove the ec2-user default user and creates the shared-user user
####################################################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# Enforce parameter
if [ "$#" -lt 1 ]; then
  echo "USAGE: instance_key"
  echo "EXAMPLE: admin"
  echo "Only provided $# arguments"
  exit 1
fi

instance_key="${1}"
logfile_nm="${instance_key}".log

####
STEP "${instance_key} box provision security."
####

get_instance_name "${instance_key}"
instance_nm="${__RESULT}"
instance_is_running "${instance_nm}"
is_running="${__RESULT}"
get_instance_state "${instance_nm}"
instance_st="${__RESULT}"

if [[ 'true' == "${is_running}" ]]
then
   echo "* ${instance_key} box ready (${instance_st})."
else
   echo "* WARN: ${instance_key} box is not ready (${instance_st})."
      
   return 0
fi

# Get the public IP address assigned to the instance. 
get_public_ip_address_associated_with_instance "${instance_nm}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo "* ERROR: ${instance_key} IP address not found."
   exit 1
else
   echo "* ${instance_key} IP address: ${eip}."
fi

get_security_group_name "${instance_key}"
sgp_nm="${__RESULT}"
get_security_group_id "${sgp_nm}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* ERROR: security group not found.'
   exit 1
else
   echo "* security group ID: ${sgp_id}."
fi

echo

# Removing old files
temporary_dir="${TMP_DIR}"/"${instance_key}"
rm -rf  "${temporary_dir:?}"
mkdir -p "${temporary_dir}"

## 
## Firewall
##

check_access_is_granted "${sgp_id}" '22' 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" '22' 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}" 
   
   echo "Access granted on 22 tcp 0.0.0.0/0."
else
   echo "WARN: access already granted on 22 tcp 0.0.0.0/0."
fi
 
get_application_port 'ssh'
ssh_port="${__RESULT}"
  
check_access_is_granted "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"  
   
    echo "Access granted on ${ssh_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${ssh_port} tcp 0.0.0.0/0."
fi

#
echo 'Provisioning the instance ...'
# 

# Verify it the SSH port is still 22 or it has changed.
get_keypair_name "${instance_key}"
keypair_nm="${__RESULT}"
private_key_file="${ACCESS_DIR}"/"${keypair_nm}"
get_user_name
user_nm="${__RESULT}"
remote_dir=/home/"${user_nm}"/script

get_ssh_port "${private_key_file}" "${eip}" "${user_nm}" '22' "${ssh_port}" 
current_ssh_port="${__RESULT}"

echo "SSH port ${current_ssh_port}."

ssh_run_remote_command "rm -rf ${remote_dir:?} && mkdir -p ${remote_dir}"/security \
    "${private_key_file}" \
    "${eip}" \
    "${current_ssh_port}" \
    "${user_nm}"                     
   
sed -e "s/SEDssh_portSED/${ssh_port}/g" \
    -e "s/AllowUsers/#AllowUsers/g" \
       "${PROVISION_DIR}"/security/sshd_config_template > "${temporary_dir}"/sshd_config
       
echo 'sshd_config ready.' 

sed -e "s/SEDscript_dirSED/$(escape "${remote_dir}")/g" \
       "${PROVISION_DIR}"/security/secure-linux.sh > "${temporary_dir}"/secure-linux.sh

echo 'secure-linux.sh ready'

scp_upload_files "${private_key_file}" "${eip}" "${current_ssh_port}" "${user_nm}" "${remote_dir}" \
    "${temporary_dir}"/secure-linux.sh \
    "${PROVISION_DIR}"/security/check-linux.sh \
    "${PROVISION_DIR}"/yumupdate.sh \
    "${temporary_dir}"/sshd_config        

get_user_password
user_pwd="${__RESULT}"

ssh_run_remote_command_as_root "chmod -R +x ${remote_dir}" \
    "${private_key_file}" \
    "${eip}" \
    "${current_ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" 

echo 'Securing the box ...'
                
set +e
# Harden the kernel, change SSH port to 38142, set ec2-user password and sudo with password.
ssh_run_remote_command_as_root "${remote_dir}"/secure-linux.sh \
    "${private_key_file}" \
    "${eip}" \
    "${current_ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}"
                   
exit_code=$?
set -e

# shellcheck disable=SC2181
if [ 194 -eq "${exit_code}" ]
then
   echo 'Box successfully secured, rebooting ...'

   set +e
   ssh_run_remote_command_as_root "reboot" \
       "${private_key_file}" \
       "${eip}" \
       "${current_ssh_port}" \
       "${user_nm}" \
       "${user_pwd}"
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
   revoke_access_from_cidr "${sgp_id}" '22' 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"  
   
   echo "Access revoked on 22 tcp 0.0.0.0/0."
else
   echo "WARN: access already revoked on 22 tcp 0.0.0.0/0."
fi

# After reboot the SSH port should be 38142
wait_ssh_started "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}"

echo "SSH port ${ssh_port}."
echo 'Running security checks ...'

ssh_run_remote_command_as_root "${remote_dir}"/check-linux.sh \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}"    
       
# Clear remote directory.
ssh_run_remote_command "rm -rf ${remote_dir:?}" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"    
    
## 
## Firewall
## 

check_access_is_granted "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'true' == "${is_granted}" ]]
then
   revoke_access_from_cidr "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"   
   
   echo "Access revoked on ${ssh_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already revoked on ${ssh_port} tcp 0.0.0.0/0."
fi

# Removing old files
rm -rf "${temporary_dir:?}"

echo "${instance_key} box provisioned security."
echo

