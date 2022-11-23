#!/bin/bash

# shellcheck disable=SC2015

#####################################################
# Runs a Docker container.
#####################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# Enforce parameter
if [ "$#" -lt 2 ]; then
  echo "USAGE: instance_key service_key"
  echo "EXAMPLE: redis redis"
  echo "Only provided $# arguments"
  exit 1
fi

instance_key="${1}"
service_key="${2}"
ssh_key='ssh-application'
consul_key='consul-application'
logfile_nm="${instance_key}".log

####
STEP "${instance_key} box provision service."
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
   if [[ -n "${instance_st}" ]]
   then
      echo "* WARN: ${instance_key} box is not ready (${instance_st})."
   else
      echo "* WARN: ${instance_key} box is not ready."
   fi
      
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

temporary_dir="${TMP_DIR}"/"${service_key}"
rm -rf  "${temporary_dir:?}"
mkdir -p "${temporary_dir}"

#
# Firewall
#

get_datacenter_application "${instance_key}" "${ssh_key}" 'Port'
ssh_port="${__RESULT}"

ec2_check_access_is_granted "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   ec2_allow_access_from_cidr "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"  
   
   echo "Access granted on ${ssh_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted on ${ssh_port} tcp 0.0.0.0/0."
fi
   
#
# Permissions.
#

get_datacenter_instance "${instance_key}" 'RoleName'
role_nm="${__RESULT}"
iam_check_role_has_permission_policy_attached "${role_nm}" "${ECR_POLICY_NM}"
is_permission_associated="${__RESULT}"

if [[ 'false' == "${is_permission_associated}" ]]
then
   echo 'Associating permission policy to the role ...'

   iam_attach_permission_policy_to_role "${role_nm}" "${ECR_POLICY_NM}"

   echo 'Permission policy associated to the role.'
else
   echo 'WARN: permission policy already associated to the role.'
fi 

#
echo "Provisioning the instance ..."
# 

get_datacenter_instance "${instance_key}" 'UserName'
user_nm="${__RESULT}"
get_datacenter_instance "${instance_key}" 'KeypairName'
keypair_nm="${__RESULT}"
private_key_file="${ACCESS_DIR}"/"${keypair_nm}" 
wait_ssh_started "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}"
remote_dir=/home/"${user_nm}"/script

ssh_run_remote_command "rm -rf ${remote_dir:?} && mkdir -p ${remote_dir}/service/${service_key}" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"  

#
# Prepare the scripts to run on the server.
#

sed -e "s/SEDremote_dirSED/$(escape "${remote_dir}"/service/"${service_key}")/g" \
    -e "s/SEDlibrary_dirSED/$(escape "${remote_dir}"/service/"${service_key}")/g" \
    -e "s/SEDconstants_dirSED/$(escape "${remote_dir}"/service/"${service_key}")/g" \
    -e "s/SEDinstance_keySED/${instance_key}/g" \
    -e "s/SEDservice_keySED/${service_key}/g" \
    -e "s/SEDconsul_keySED/${consul_key}/g" \
    -e "s/SEDcontainer_nmSED/${service_key}/g" \
       "${SERVICES_DIR}"/container-run.sh > "${temporary_dir}"/container-run.sh  
  
echo 'container-run.sh ready.'      
  
scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}/service/${service_key}" \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/service_consts_utils.sh \
    "${LIBRARY_DIR}"/datacenter_consts_utils.sh \
    "${LIBRARY_DIR}"/network.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr_registry.sh \
    "${temporary_dir}"/container-run.sh \
    "${CONSTANTS_DIR}"/datacenter_consts.json \
    "${CONSTANTS_DIR}"/service_consts.json      
    
get_datacenter_instance "${instance_key}" 'UserPassword'
user_pwd="${__RESULT}"

ssh_run_remote_command_as_root "chmod -R +x ${remote_dir}/service/${service_key}" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" 
    
ssh_run_remote_command_as_root "${remote_dir}/service/${service_key}/container-run.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Service successfully provisioned.' ||
    {    
       echo 'WARN: changes made to IAM entities can take noticeable time for the information to be reflected globally.'
       echo 'Let''s wait a bit and check again.' 
      
       wait 60  
      
       echo 'Let''s try now.' 
    
       ssh_run_remote_command_as_root "${remote_dir}/service/${service_key}/container-run.sh" \
          "${private_key_file}" \
          "${eip}" \
          "${ssh_port}" \
          "${user_nm}" \
          "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Service successfully provisioned.' ||
          {
              echo 'ERROR: the problem persists after 3 minutes.'
              exit 1          
          }
    }
        
ssh_run_remote_command "rm -rf ${remote_dir:?}" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" 
    
#
# Permissions.
#

iam_check_role_has_permission_policy_attached "${role_nm}" "${ECR_POLICY_NM}"
is_permission_associated="${__RESULT}"

if [[ 'true' == "${is_permission_associated}" ]]
then
   echo 'Detatching permission policy from role ...'
   
   iam_detach_permission_policy_from_role "${role_nm}" "${ECR_POLICY_NM}"
      
   echo 'Permission policy detached from role.'
else
   echo 'WARN: permission policy already detached from role.'
fi 

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
   echo "WARN: access already revoked ${ssh_port} tcp 0.0.0.0/0."
fi

get_service_application "${service_key}" 'HostPort'
application_port="${__RESULT}"

ec2_check_access_is_granted "${sgp_id}" "${application_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   ec2_allow_access_from_cidr "${sgp_id}" "${application_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"  
   
   echo "Access granted on ${application_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted on ${application_port} tcp 0.0.0.0/0."
fi

# Removing old files
# shellcheck disable=SC2115
rm -rf  "${temporary_dir:?}"

echo "${instance_key} box service provisioned."

get_service_webapp_url "${service_key}" "${eip}" "${application_port}"
webapp_url="${__RESULT}"

if [[ -n "${webapp_url}" ]]
then
   echo "${webapp_url}"
fi

echo

