#!/bin/bash

# shellcheck disable=SC2015

#########################################################
# The script provisinos the scripts to the Admin jumpbox,
# builds the base images and push them to ECR.
#########################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR=/home/"${USER_NM}"/script

####
STEP 'AWS ECR'
####

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

# Jumpbox where the images are built.
get_instance_id "${ADMIN_INST_NM}"
admin_instance_id="${__RESULT}"

if [[ -z "${admin_instance_id}" ]]
then
   echo '* ERROR: Admin instance not found.'
   exit 1
fi

if [[ -n "${admin_instance_id}" ]]
then
   get_instance_state "${ADMIN_INST_NM}"
   admin_instance_st="${__RESULT}"
   
   if [[ 'running' == "${admin_instance_st}" ]]
   then
      echo "* Admin box ready (${admin_instance_st})."
   else
      echo "* ERROR: Admin box is not ready. (${admin_instance_st})."
      
      exit 1
   fi
fi

get_security_group_id "${ADMIN_INST_SEC_GRP_NM}"
admin_sgp_id="${__RESULT}"

if [[ -z "${admin_sgp_id}" ]]
then
   echo '* ERROR: Admin security group not found.'
   exit 1
else
   echo "* Admin security group ID: ${admin_sgp_id}."
fi

# Removing old files
# shellcheck disable=SC2115
ecr_tmp_dir="${TMP_DIR}"/ecr
rm -rf  "${ecr_tmp_dir:?}"
mkdir -p "${ecr_tmp_dir}"

echo

#
# Admin jumpbox
#

set +e
allow_access_from_cidr "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e
   
echo 'Granted SSH access to the Admin box.'

#
# Permissions.
#

check_instance_profile_has_role_associated "${ADMIN_INST_PROFILE_NM}" "${ADMIN_AWS_ROLE_NM}" 
is_role_associated="${__RESULT}"

if [[ 'false' == "${is_role_associated}" ]]
then
   echo 'Associating permission policy the Admin instance role ...'

   associate_role_to_instance_profile "${ADMIN_INST_PROFILE_NM}" "${ADMIN_AWS_ROLE_NM}"
      
   # IAM is a bit slow, progress only when the role is associated to the profile. 
   check_instance_profile_has_role_associated "${ADMIN_INST_PROFILE_NM}" "${ADMIN_AWS_ROLE_NM}" && \
   echo 'Role associated to the Admin instance profile.' ||
   {
      echo 'The role has not been associated to the profile yet.'
      echo 'Let''s wait a bit and check again (first time).' 
      
      wait 180  
      
      echo 'Let''s try now.' 
      
      check_instance_profile_has_role_associated "${ADMIN_INST_PROFILE_NM}" "${ADMIN_AWS_ROLE_NM}" && \
      echo 'Role associated to the instance profile.' ||
      {
         echo 'ERROR: the role has not been associated to the profile after 3 minutes.'
         exit 1
      }
   } 
else
   echo 'WARN: role already associated to the instance profile.'
fi 

check_role_has_permission_policy_attached "${ADMIN_AWS_ROLE_NM}" "${ECR_POLICY_NM}"
is_permission_policy_associated="${__RESULT}"

if [[ 'false' == "${is_permission_policy_associated}" ]]
then
   echo 'Attaching permission policy to the role ...'
   
   attach_permission_policy_to_role "${ADMIN_AWS_ROLE_NM}" "${ECR_POLICY_NM}"
      
   # IAM is a bit slow, progress only when the role is associated to the profile. 
   check_role_has_permission_policy_attached "${ADMIN_AWS_ROLE_NM}" "${ECR_POLICY_NM}" && \
   echo 'Permission policy associated to the role.' ||
   {
      echo 'The permission policy has not been associated to the role yet.'
      echo 'Let''s wait a bit and check again (first time).' 
      
      wait 180  
      
      echo 'Let''s try now.' 
      
      check_role_has_permission_policy_attached "${ADMIN_AWS_ROLE_NM}" "${ECR_POLICY_NM}" && \
      echo 'Permission policy associated to the role.' ||
      {
         echo 'ERROR: the permission policy has not been associated to the role after 3 minutes.'
         exit 1
      }
   } 
else
   echo 'WARN: permission policy already associated to the role.'
fi 

# Get the public IP address assigned to the instance. 
get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}"
admin_eip="${__RESULT}"

echo "Admin box public address: ${admin_eip}."
echo 'Provisioning the Admin instance ...'

private_key_file="${ACCESS_DIR}"/"${ADMIN_INST_KEY_PAIR_NM}" 
wait_ssh_started "${private_key_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}"

ssh_run_remote_command "rm -rf ${SCRIPTS_DIR} && mkdir -p ${SCRIPTS_DIR}/centos/dockerctx && mkdir -p ${SCRIPTS_DIR}/ruby/dockerctx" \
    "${private_key_file}" \
    "${admin_eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}"
    
# Prepare the scripts to run on the server.
mkdir -p "${ecr_tmp_dir}"/centos
mkdir -p "${ecr_tmp_dir}"/ruby

# Centos scripts
echo 'Provisioning Centos scripts ...'

ecr_get_repostory_uri "${CENTOS_DOCKER_IMG_NM}"
centos_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}/centos")/g" \
    -e "s/SEDcentos_docker_ctxSED/$(escape "${SCRIPTS_DIR}"/centos/dockerctx)/g" \
    -e "s/SEDcentos_docker_repository_uriSED/$(escape "${centos_docker_repository_uri}")/g" \
    -e "s/SEDcentos_docker_img_nmSED/$(escape "${CENTOS_DOCKER_IMG_NM}")/g" \
    -e "s/SEDcentos_docker_img_tagSED/${CENTOS_DOCKER_IMG_TAG}/g" \
       "${SERVICES_DIR}"/base/centos/centos.sh > "${ecr_tmp_dir}"/centos/centos.sh  
       
echo 'centos.sh ready.' 

scp_upload_file "${private_key_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}"/centos/dockerctx \
    "${SERVICES_DIR}"/base/centos/Dockerfile  
    
scp_upload_files "${private_key_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}"/centos \
    "${LIBRARY_DIR}"/constants/app_consts.sh \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${ecr_tmp_dir}"/centos/centos.sh 
    
echo 'Centos scripts provisioned.'
echo         

# Ruby scripts

echo 'Provisioning Ruby scripts ...'

ecr_get_repostory_uri "${RUBY_DOCKER_IMG_NM}"
ruby_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}/ruby")/g" \
    -e "s/SEDruby_docker_ctxSED/$(escape "${SCRIPTS_DIR}"/ruby/dockerctx)/g" \
    -e "s/SEDruby_docker_repository_uriSED/$(escape "${ruby_docker_repository_uri}")/g" \
    -e "s/SEDruby_docker_img_nmSED/$(escape "${RUBY_DOCKER_IMG_NM}")/g" \
    -e "s/SEDruby_docker_img_tagSED/${RUBY_DOCKER_IMG_TAG}/g" \
       "${SERVICES_DIR}"/base/ruby/ruby.sh > "${ecr_tmp_dir}"/ruby/ruby.sh  
       
echo 'ruby.sh ready.' 

sed -e "s/SEDruby_docker_repository_uriSED/$(escape "${centos_docker_repository_uri}")/g" \
    -e "s/SEDruby_docker_img_tagSED/${CENTOS_DOCKER_IMG_TAG}/g" \
       "${SERVICES_DIR}"/base/ruby/Dockerfile > "${ecr_tmp_dir}"/ruby/Dockerfile
       
echo 'ruby Dockerfile ready.'        

scp_upload_file "${private_key_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}"/ruby/dockerctx \
    "${ecr_tmp_dir}"/ruby/Dockerfile
     
scp_upload_files "${private_key_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}"/ruby \
    "${LIBRARY_DIR}"/constants/app_consts.sh \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${ecr_tmp_dir}"/ruby/ruby.sh     

echo 'Ruby scripts provisioned.' 
echo   

ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR}" \
    "${private_key_file}" \
    "${admin_eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}"       
    
echo 'Building Centos Docker image ...'
           
# build Centos Docker images in the admin box and send it to ECR.                             
ssh_run_remote_command_as_root "${SCRIPTS_DIR}/centos/centos.sh" \
    "${private_key_file}" \
    "${admin_eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" && echo 'Centos Docker image successfully built.' ||
    {    
       echo 'The role may not have been associated to the profile yet.'
       echo 'Let''s wait a bit and check again (first time).' 
      
       wait 180  
      
       echo 'Let''s try now.' 
    
       ssh_run_remote_command_as_root "${SCRIPTS_DIR}/centos/centos.sh" \
          "${private_key_file}" \
          "${admin_eip}" \
          "${SHARED_INST_SSH_PORT}" \
          "${USER_NM}" \
          "${USER_PWD}" && echo 'Centos Docker image successfully built.' ||
          {
              echo 'ERROR: the problem persists after 3 minutes.'
              exit 1          
          }
    }

echo
echo 'Building Ruby Docker image ...'
           
set +e   
# build Ruby Docker images in the admin box and send it to ECR.                             
ssh_run_remote_command_as_root "${SCRIPTS_DIR}/ruby/ruby.sh" \
    "${private_key_file}" \
    "${admin_eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" 
                            
exit_code=$?
set -e

# shellcheck disable=SC2181
if [[ 0 -eq "${exit_code}" ]]
then
   echo 'Ruby Docker image successfully built.'    
else
   echo 'ERROR: building Ruby.'
   exit 1
fi

ssh_run_remote_command "rm -rf ${SCRIPTS_DIR}" \
    "${private_key_file}" \
    "${admin_eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}"  
    
#
# Permissions.
#

check_role_has_permission_policy_attached "${ADMIN_AWS_ROLE_NM}" "${ECR_POLICY_NM}"
is_permission_policy_associated="${__RESULT}"

if [[ 'true' == "${is_permission_policy_associated}" ]]
then
   echo 'Detaching permission policy from role ...'
   
   detach_permission_policy_from_role "${ADMIN_AWS_ROLE_NM}" "${ECR_POLICY_NM}"
      
   echo 'Permission policy detached.'
else
   echo 'WARN: permission policy already detached from the role.'
fi 

## 
## SSH Access.
##

set +e
   revoke_access_from_cidr "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e

echo 'Revoked SSH access to the Admin box.'      

echo

# Removing old files
# shellcheck disable=SC2115
rm -rf  "${ecr_tmp_dir:?}"




