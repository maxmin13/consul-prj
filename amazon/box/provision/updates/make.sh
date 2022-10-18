#!/usr/bin/bash

####################################################################################
# Installs Docker, updates awscli to version 2.
####################################################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# Enforce parameter
if [ "$#" -lt 1 ]; then
  echo "USAGE: instance_key"
  echo "EXAMPLE: admin-ik"
  echo "Only provided $# arguments"
  exit 1
fi

instance_key="${1}"
logfile_nm="${instance_key}".log

####
STEP "${instance_key} box provision updates."
####

get_datacenter_instance "${instance_key}" 'Name'
instance_nm="${__RESULT}"
ec2_instance_is_running "${instance_nm}"
is_running="${__RESULT}"
ec2_get_instance_state "${instance_nm}"
instance_st="${__RESULT}"

if [[ 'true' == "${is_running}" ]]
then
   echo "* ${instance_key} box ready (${instance_st})."
else
   echo "* WARN: ${instance_key} box is not ready (${instance_st})."
      
   return 0
fi

# Get the public IP address assigned to the instance. 
ec2_get_public_ip_address_associated_with_instance "${instance_nm}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo "* ERROR: ${instance_key} IP address not found."
   exit 1
else
   echo "* ${instance_key} IP address: ${eip}."
fi

get_datacenter_instance "${instance_key}" 'SgpName'
sgp_nm="${__RESULT}"
ec2_get_security_group_id "${sgp_nm}"
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
 
get_datacenter_application "${instance_key}" 'ssh' 'Port'
ssh_port="${__RESULT}"
ec2_check_access_is_granted "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   ec2_allow_access_from_cidr "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"  
   
    echo "Access granted on ${ssh_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${ssh_port} tcp 0.0.0.0/0."
fi

#
echo 'Provisioning the instance ...'
# 

get_datacenter_instance "${instance_key}" 'KeypairName'
keypair_nm="${__RESULT}"
private_key_file="${ACCESS_DIR}"/"${keypair_nm}"
get_datacenter_instance "${instance_key}" 'UserName'
user_nm="${__RESULT}"
remote_dir=/home/"${user_nm}"/script

ssh_run_remote_command "rm -rf ${remote_dir:?} && mkdir -p ${remote_dir}"/updates \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"                     
   
sed -e "s/SEDremote_dirSED/$(escape "${remote_dir}"/updates)/g" \
       "${PROVISION_DIR}"/docker/docker-install.sh > "${temporary_dir}"/docker-install.sh    
       
echo 'docker-install.sh ready.'    

sed -e "s/SEDremote_dirSED/$(escape "${remote_dir}"/updates)/g" \
       "${PROVISION_DIR}"/awscli/awscli-update.sh > "${temporary_dir}"/awscli-update.sh    
       
echo 'awscli-update.sh ready.'   

scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/updates \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${temporary_dir}"/docker-install.sh \
    "${temporary_dir}"/awscli-update.sh      

get_datacenter_instance "${instance_key}" 'UserPassword'
user_pwd="${__RESULT}"

ssh_run_remote_command_as_root "chmod -R +x ${remote_dir}" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" 
    
echo 'Installing Docker ...'
                  
# shellcheck disable=SC2015                     
ssh_run_remote_command_as_root "${remote_dir}"/updates/docker-install.sh \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Docker successfully installed.' ||
    {
       echo 'ERROR: installing Docker.'
       exit 1    
    }
    
echo 'Updating awscli ...'
   
# shellcheck disable=SC2015                              
ssh_run_remote_command_as_root "${remote_dir}"/updates/awscli-update.sh \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'awscli successfully updated.' ||
    {
       echo 'ERROR: updating awscli.'
       exit 1    
    }    
   
# Clear remote directory.
ssh_run_remote_command "rm -rf ${remote_dir:?}" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"    
    
## 
## Firewall
## 

ec2_check_access_is_granted "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'true' == "${is_granted}" ]]
then
   ec2_revoke_access_from_cidr "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"   
   
   echo "Access revoked on ${ssh_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already revoked on ${ssh_port} tcp 0.0.0.0/0."
fi

# Removing old files
rm -rf "${temporary_dir:?}"

echo "${instance_key} box updated."
echo

