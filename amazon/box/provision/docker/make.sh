#!/usr/bin/bash

# shellcheck disable=SC2153

####################################################################################
# Installs Docker.
####################################################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

get_user_name
user_nm="${__RESULT}"
remote_script_dir=/home/"${user_nm}"/script

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
STEP "${instance_key} box provision Docker."
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
tmp_dir="${TMP_DIR}"/"${instance_key}"
rm -rf  "${tmp_dir:?}"
mkdir -p "${tmp_dir}"

remote_tmp_dir="${remote_script_dir}"/"${instance_key}"


## 
## Firewall
##
 
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

get_keypair_name "${instance_key}"
keypair_nm="${__RESULT}"
private_key_file="${ACCESS_DIR}"/"${keypair_nm}"

ssh_run_remote_command "rm -rf ${remote_script_dir:?} && mkdir -p ${remote_tmp_dir}" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"                     
   
sed -e "s/SEDscripts_dirSED/$(escape "${remote_tmp_dir}")/g" \
       "${PROVISION_DIR}"/docker/docker.sh > "${tmp_dir}"/docker.sh    
       
echo 'docker.sh ready.'     

scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_tmp_dir}" \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${tmp_dir}"/docker.sh       

get_user_password
user_pwd="${__RESULT}"

ssh_run_remote_command_as_root "chmod -R +x ${remote_tmp_dir}" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" 
    
echo 'Installing Docker ...'

set +e                                
ssh_run_remote_command_as_root "${remote_tmp_dir}"/docker.sh \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}"  
                            
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
ssh_run_remote_command "rm -rf ${remote_script_dir:?}" \
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
rm -rf "${tmp_dir:?}"

echo "${instance_key} box provisioned Docker."
echo

