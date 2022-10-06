#!/bin/bash

#####################################################################
# The script uploads to the Admin jumpbox the Docker files and builds
# all the images in the file docker_consts.json. The images are 
# pushed to the ECR registry.
#
#####################################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

instance_key='admin'
logfile_nm="${instance_key}".log

####
STEP "ECR registry"
####

get_instance "${instance_key}" 'Name'
instance_nm="${__RESULT}"
ec2_instance_is_running "${instance_nm}"
is_running="${__RESULT}"
ec2_get_instance_state "${instance_nm}"
instance_st="${__RESULT}"

if [[ 'true' == "${is_running}" ]]
then
   echo "* ${instance_key} jumpbox ready (${instance_st})."
else
   echo "* WARN: ${instance_key} jumpbox is not ready (${instance_st})."
      
   return 0
fi

ec2_get_public_ip_address_associated_with_instance "${instance_nm}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo "* ERROR: ${instance_key} jumpbox IP address not found."
   exit 1
else
   echo "* ${instance_key} jumpbox IP address: ${eip}."
fi

get_instance "${instance_key}" 'SgpName'
sgp_nm="${__RESULT}"
ec2_get_security_group_id "${sgp_nm}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo "* ERROR:  ${instance_key} jumpbox security group not found."
   exit 1
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

get_application "${instance_key}" 'ssh' 'Port'
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

get_instance "${instance_key}" 'RoleName'
role_nm="${__RESULT}"

iam_check_role_has_permission_policy_attached "${role_nm}" "${ECR_POLICY_NM}"
is_permission_associated="${__RESULT}"

if [[ 'false' == "${is_permission_associated}" ]]
then
   echo 'Attaching permission policy to the role ...'

   iam_attach_permission_policy_to_role "${role_nm}" "${ECR_POLICY_NM}"
      
   echo 'Permission policy associated to the role.' 
else
   echo 'WARN: permission policy already associated to the role.'
fi   

get_instance "${instance_key}" 'UserName'
user_nm="${__RESULT}"
get_instance "${instance_key}" 'KeypairName'
keypair_nm="${__RESULT}"
private_key_file="${ACCESS_DIR}"/"${keypair_nm}" 

wait_ssh_started "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}"

remote_dir=/home/"${user_nm}"/script
    
ssh_run_remote_command "rm -rf ${remote_dir:?}" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"

get_service_keys
# shellcheck disable=SC2206
declare -a service_keys=(${__RESULT})

for service_key in "${service_keys[@]}"
do
   echo "Provisioning ${service_key} build scripts ..."
     
   mkdir -p "${temporary_dir}"/"${service_key}"
   
   ssh_run_remote_command "mkdir -p ${remote_dir}/${service_key}/dockerctx && mkdir -p ${remote_dir}/${service_key}/constants" \
       "${private_key_file}" \
       "${eip}" \
       "${ssh_port}" \
       "${user_nm}" 
   
   #
   # Dockerfile
   #
   
   current_date="$(date +%m-%d-%Y)"
   get_service_image "${service_key}" 'BaseName'
   base_image_nm="${__RESULT}"
   get_service_image "${service_key}" 'BaseTag'
   base_image_tag="${__RESULT}"  
   get_service_port "${service_key}" 'ContainerPort'
   container_port="${__RESULT}"
   get_service_volume "${service_key}" 'ContainerDir'
   container_volume_dir="${__RESULT}"
   
   # get the name of the directory containing Dockerfile
   get_service_sources_directory "${service_key}"
   sources_dir="${__RESULT}"

   sed -e "s/SEDrepository_uriSED/$(escape "${base_image_nm}")/g" \
       -e "s/SEDimg_tagSED/${base_image_tag}/g" \
       -e "s/SEDrefreshed_atSED/${current_date}/g" \
       -e "s/SEDhttp_portSED/${container_port}/g" \
       -e "s/SEDcontainer_volume_dirSED/$(escape "${container_volume_dir}")/g" \
          "${SERVICES_DIR}"/"${sources_dir}"/Dockerfile > "${temporary_dir}"/"${service_key}"/Dockerfile    
    
   echo 'Dockerfile ready.' 
   
   scp_upload_file "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/"${service_key}"/dockerctx \
       "${temporary_dir}"/"${service_key}"/Dockerfile 
   
   #
   # configuration files
   #    
   
   get_service_image_iterate "${service_key}" 'ConfigFiles'
   config_files="${__RESULT}"
   
   if [[ -n "${config_files}" ]]
   then
      # shellcheck disable=SC2206
      declare -a files=(${config_files})

      for file in "${files[@]}"
      do      
         sed -e "s/SEDcontainer_volume_dirSED/$(escape "${container_volume_dir}")/g" \
             -e "s/SEDhttp_portSED/${container_port}/g" \
                "${SERVICES_DIR}"/"${sources_dir}"/"${file}" > "${temporary_dir}"/"${service_key}"/"${file}"   
             
         echo "${file} ready."   
      
         scp_upload_file "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/"${service_key}"/dockerctx \
               "${temporary_dir}"/"${service_key}"/"${file}"              
      done
   fi
   
   #
   # build scripts
   #
  
   sed -e "s/SEDlibrary_dirSED/$(escape "${remote_dir}"/"${service_key}")/g" \
       -e "s/SEDdocker_ctxSED/$(escape "${remote_dir}"/"${service_key}"/dockerctx)/g" \
       -e "s/SEDservice_keySED/${service_key}/g" \
          "${SERVICES_DIR}"/image-build.sh > "${temporary_dir}"/"${service_key}"/"${service_key}"-build.sh  
      
   echo "${service_key}-build.sh ready."     
 
   scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/"${service_key}" \
       "${LIBRARY_DIR}"/service_consts_utils.sh \
       "${LIBRARY_DIR}"/datacenter_consts_utils.sh \
       "${LIBRARY_DIR}"/dockerlib.sh \
       "${LIBRARY_DIR}"/registry.sh \
       "${temporary_dir}"/"${service_key}"/"${service_key}"-build.sh
       
   scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/"${service_key}"/constants \
       "${LIBRARY_DIR}"/constants/datacenter_consts.json \
       "${LIBRARY_DIR}"/constants/service_consts.json
    
   echo "Building ${service_key} image ..."

   get_instance "${instance_key}" 'UserPassword'
   user_pwd="${__RESULT}"
           
   # build the image in the box and send it to ECR registry.                             
   # shellcheck disable=SC2015
   ssh_run_remote_command_as_root "chmod -R +x ${remote_dir} && ${remote_dir}/${service_key}/${service_key}-build.sh" \
       "${private_key_file}" \
       "${eip}" \
       "${ssh_port}" \
       "${user_nm}" \
       "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo "${service_key} image successfully built." ||
       {    
          echo 'WARN: changes made to IAM entities can take noticeable time for the information to be reflected globally.'
          echo 'Let''s wait a bit and check again.' 
      
          wait 60  
      
          echo 'Let''s try now.' 
    
          ssh_run_remote_command_as_root "${remote_dir}/${service_key}/${service_key}-build.sh" \
             "${private_key_file}" \
             "${eip}" \
             "${ssh_port}" \
             "${user_nm}" \
             "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo "${service_key} image successfully built." ||
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

