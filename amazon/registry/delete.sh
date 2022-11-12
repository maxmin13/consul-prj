#!/bin/bash

#####################################################################
# The script deletes all ECR repositories created and clear Docker
# images and containers in the Admin jumpbox.
#####################################################################

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

ssh_key='ssh-application'
instance_key="${1}"
logfile_nm="${instance_key}".log

####
STEP "ECR registry"
####

get_datacenter_instance "${instance_key}" 'Name'
instance_nm="${__RESULT}"
ec2_instance_is_running "${instance_nm}"
is_running="${__RESULT}"
ec2_get_instance_state "${instance_nm}"
instance_st="${__RESULT}"

if [[ 'true' == "${is_running}" ]]
then
   echo "* ${instance_key} jumpbox ready (${instance_st})."
else
   if [[ -n "${instance_st}" ]]
   then
      echo "* WARN: ${instance_key} jumpbox is not ready (${instance_st})."
   else
      echo "* WARN: ${instance_key} jumpbox is not ready."
   fi
      
   return 0
fi
 
ec2_get_public_ip_address_associated_with_instance "${instance_nm}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo "* WARN: ${instance_key} jumpbox IP address not found."
else
   echo "* ${instance_key} jumpbox IP address: ${eip}."
fi

get_datacenter_instance "${instance_key}" 'SgpName'
sgp_nm="${__RESULT}"
ec2_get_security_group_id "${sgp_nm}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo "* WARN: ${instance_key} jumpbox security group not found."
else
   echo "* ${instance_key} jumpbox security group ID: ${sgp_id}."
fi

temporary_dir="${TMP_DIR}"/ecr
rm -rf  "${temporary_dir:?}"
mkdir -p "${temporary_dir}"

echo

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

# Permissions.
#

get_datacenter_instance "${instance_key}" 'RoleName'
role_nm="${__RESULT}"

iam_check_role_has_permission_policy_attached "${role_nm}" "${ECR_POLICY_NM}"
is_permission_policy_associated="${__RESULT}"

if [[ 'false' == "${is_permission_policy_associated}" ]]
then
   echo 'Attaching permission policy to the role ...'

   iam_attach_permission_policy_to_role "${role_nm}" "${ECR_POLICY_NM}"
      
   echo 'Permission policy associated to the role.' 
else
   echo 'WARN: permission policy already associated to the role.'
fi

get_datacenter_instance "${instance_key}" 'UserName'
user_nm="${__RESULT}"
get_datacenter_instance "${instance_key}" 'KeypairName'
keypair_nm="${__RESULT}"
private_key_file="${ACCESS_DIR}"/"${keypair_nm}" 

wait_ssh_started "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}"

remote_dir=/home/"${user_nm}"/script
    
ssh_run_remote_command "rm -rf ${remote_dir:?}" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"

# get the keys of the services from service_consts.json file.
get_service_keys

# shellcheck disable=SC2206
declare -a service_keys=(${__RESULT})

for service_key in "${service_keys[@]}"
do
   echo "Provisioning ${service_key} build scripts ..."
   
   mkdir -p "${temporary_dir}"/"${service_key}"
   
   ssh_run_remote_command "mkdir -p ${remote_dir}/${service_key}" \
       "${private_key_file}" \
       "${eip}" \
       "${ssh_port}" \
       "${user_nm}" 
           
   sed -e "s/SEDlibrary_dirSED/$(escape "${remote_dir}"/"${service_key}")/g" \
       -e "s/SEDconstants_dirSED/$(escape "${remote_dir}"/"${service_key}")/g" \
       -e "s/SEDservice_keySED/${service_key}/g" \
          "${SERVICES_DIR}"/image-remove.sh > "${temporary_dir}"/"${service_key}"/"${service_key}"-remove.sh    

   echo "${service_key}-remove.sh  ready."  

   scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/"${service_key}" \
      "${LIBRARY_DIR}"/dockerlib.sh \
      "${LIBRARY_DIR}"/service_consts_utils.sh \
      "${LIBRARY_DIR}"/datacenter_consts_utils.sh \
      "${LIBRARY_DIR}"/registry.sh \
      "${temporary_dir}"/"${service_key}"/"${service_key}"-remove.sh \
      "${CONSTANTS_DIR}"/datacenter_consts.json \
      "${CONSTANTS_DIR}"/service_consts.json           
      
   echo 'Deleting image and ECR repository ...'

   get_datacenter_instance "${instance_key}" 'UserPassword'
   user_pwd="${__RESULT}"

   # remove image in the box and in ECR.                             
   # shellcheck disable=SC2015
   ssh_run_remote_command_as_root "chmod -R +x ${remote_dir} && ${remote_dir}/${service_key}/${service_key}-remove.sh" \
       "${private_key_file}" \
       "${eip}" \
       "${ssh_port}" \
       "${user_nm}" \
        "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Image successfully removed.' ||
        {    
           echo 'WARN: changes made to IAM entities can take noticeable time for the information to be reflected globally.'
           echo 'Let''s wait a bit and check again.' 
      
           wait 60  
      
           echo 'Let''s try now.' 
    
           ssh_run_remote_command_as_root "${remote_dir}/${service_key}/${service_key}-remove.sh" \
              "${private_key_file}" \
              "${eip}" \
              "${ssh_port}" \
              "${user_nm}" \
              "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Image successfully removed.' ||
              {
                  echo 'ERROR: the problem persists after 3 minutes.'
                  exit 1          
              }
        }  
    echo     
done

echo         
                
ssh_run_remote_command "rm -rf ${remote_dir:?}" \
  "${private_key_file}" \
  "${eip}" \
  "${ssh_port}" \
  "${user_nm}"

#
# Permissions.
#

iam_check_role_has_permission_policy_attached "${role_nm}" "${ECR_POLICY_NM}"
is_permission_policy_associated="${__RESULT}"

if [[ 'true' == "${is_permission_policy_associated}" ]]
then
  echo 'Detaching permission policy from role ...'

  iam_detach_permission_policy_from_role "${role_nm}" "${ECR_POLICY_NM}"

  echo 'Permission policy detached.'
else
  echo 'WARN: permission policy already detached from the role.'
fi 

## 
## Firewall.
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

echo 'Revoked SSH access to the box.'      
echo

# Removing old files
# shellcheck disable=SC2115
rm -rf  "${temporary_dir:?}"

