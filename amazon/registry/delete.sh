#!/bin/bash

# shellcheck disable=SC2015

#####################################################################
# The script deletes all ECR repositories created and clear Docker
# images and containers in the Admin jumpbox.
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

get_instance_name "${instance_key}"
instance_nm="${__RESULT}"
instance_is_running "${instance_nm}"
is_running="${__RESULT}"
get_instance_state "${instance_nm}"
instance_st="${__RESULT}"

if [[ 'true' == "${is_running}" ]]
then
   echo "* ${instance_key} jumpbox ready (${instance_st})."
else
   echo "* WARN: ${instance_key} jumpbox is not ready (${instance_st})."
      
   return 0
fi
 
get_public_ip_address_associated_with_instance "${instance_nm}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo "* WARN: ${instance_key} jumpbox IP address not found."
else
   echo "* ${instance_key} jumpbox IP address: ${eip}."
fi

get_security_group_name "${instance_key}"
sgp_nm="${__RESULT}"
get_security_group_id "${sgp_nm}"
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

get_application_port 'ssh'
ssh_port="${__RESULT}"
check_access_is_granted "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access granted on ${ssh_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted on ${ssh_port} tcp 0.0.0.0/0."
fi

# Permissions.
#

get_role_name "${instance_key}"
role_nm="${__RESULT}"

check_role_has_permission_policy_attached "${role_nm}" "${ECR_POLICY_NM}"
is_permission_policy_associated="${__RESULT}"

if [[ 'false' == "${is_permission_policy_associated}" ]]
then
   echo 'Attaching permission policy to the role ...'

   attach_permission_policy_to_role "${role_nm}" "${ECR_POLICY_NM}"
      
   echo 'Permission policy associated to the role.' 
else
   echo 'WARN: permission policy already associated to the role.'
fi

get_user_name
user_nm="${__RESULT}"
get_keypair_name "${instance_key}"
keypair_nm="${__RESULT}"
private_key_file="${ACCESS_DIR}"/"${keypair_nm}" 

wait_ssh_started "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}"

remote_dir=/home/"${user_nm}"/script

# Prepare the scripts to run on the server.

ssh_run_remote_command "rm -rf ${remote_dir:?}" \
  "${private_key_file}" \
  "${eip}" \
  "${ssh_port}" \
  "${user_nm}"

#
# Jenkins
#

echo 'Provisioning Jenkins scripts ...'

mkdir -p "${temporary_dir}"/jenkins

ssh_run_remote_command "mkdir -p ${remote_dir}/jenkins" \
  "${private_key_file}" \
  "${eip}" \
  "${ssh_port}" \
  "${user_nm}"

get_region_name
region="${__RESULT}"
ecr_get_registry_uri "${region}"
registry_uri="${__RESULT}"
ecr_get_repostory_uri "${JENKINS_DOCKER_IMG_NM}" "${registry_uri}"
jenkins_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${remote_dir}/jenkins")/g" \
  -e "s/SEDregionSED/${region}/g" \
  -e "s/SEDdocker_repository_uriSED/$(escape "${jenkins_docker_repository_uri}")/g" \
  -e "s/SEDdocker_img_nmSED/$(escape "${JENKINS_DOCKER_IMG_NM}")/g" \
  -e "s/SEDdocker_img_tagSED/${JENKINS_DOCKER_IMG_TAG}/g" \
    "${CONTAINERS_DIR}"/image-remove.sh > "${temporary_dir}"/jenkins/jenkins-remove.sh    

echo 'jenkins-remove.sh ready.'        

scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/jenkins \
  "${LIBRARY_DIR}"/dockerlib.sh \
  "${LIBRARY_DIR}"/ecr.sh \
  "${temporary_dir}"/jenkins/jenkins-remove.sh     

echo 'Deleting Jenkins image and ECR repository ...'

get_user_password
user_pwd="${__RESULT}"

# remove Jenkins image in the box and in ECR.                             
ssh_run_remote_command_as_root "chmod -R +x ${remote_dir} && ${remote_dir}/jenkins/jenkins-remove.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Jenkins image successfully removed.' ||
    {    
       echo 'WARN: changes made to IAM entities can take noticeable time for the information to be reflected globally.'
       echo 'Let''s wait a bit and check again.' 
      
       wait 120  
      
       echo 'Let''s try now.' 
    
       ssh_run_remote_command_as_root "${remote_dir}/jenkins/jenkins-remove.sh" \
          "${private_key_file}" \
          "${eip}" \
          "${ssh_port}" \
          "${user_nm}" \
          "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Jenkins image successfully removed.' ||
          {
              echo 'ERROR: the problem persists after 3 minutes.'
              exit 1          
          }
    }
    
echo   

#
# Nginx
#

echo 'Provisioning Nginx scripts ...'

mkdir -p "${temporary_dir}"/nginx

ssh_run_remote_command "mkdir -p ${remote_dir}/nginx" \
  "${private_key_file}" \
  "${eip}" \
  "${ssh_port}" \
  "${user_nm}"

ecr_get_repostory_uri "${NGINX_DOCKER_IMG_NM}" "${registry_uri}"
nginx_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${remote_dir}/nginx")/g" \
  -e "s/SEDregionSED/${region}/g" \
  -e "s/SEDdocker_repository_uriSED/$(escape "${nginx_docker_repository_uri}")/g" \
  -e "s/SEDdocker_img_nmSED/$(escape "${NGINX_DOCKER_IMG_NM}")/g" \
  -e "s/SEDdocker_img_tagSED/${NGINX_DOCKER_IMG_TAG}/g" \
    "${CONTAINERS_DIR}"/image-remove.sh > "${temporary_dir}"/nginx/nginx-remove.sh  

echo 'nginx-remove.sh ready.'        

scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/nginx \
  "${LIBRARY_DIR}"/dockerlib.sh \
  "${LIBRARY_DIR}"/ecr.sh \
  "${temporary_dir}"/nginx/nginx-remove.sh     

echo 'Deleting Nginx image and ECR repository ...'
                             
ssh_run_remote_command_as_root "chmod -R +x ${remote_dir} && ${remote_dir}/nginx/nginx-remove.sh" \
  "${private_key_file}" \
  "${eip}" \
  "${ssh_port}" \
  "${user_nm}" \
  "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Nginx image and ECR repository successfully deleted.' ||
  {
     echo 'ERROR: deleting Nginx.'
     exit 1   
  }

echo 

#
# Sinatra
#

echo 'Provisioning Sinatra scripts ...'

mkdir -p "${temporary_dir}"/sinatra

ssh_run_remote_command "mkdir -p ${remote_dir}/sinatra" \
  "${private_key_file}" \
  "${eip}" \
  "${ssh_port}" \
  "${user_nm}"

ecr_get_repostory_uri "${SINATRA_DOCKER_IMG_NM}" "${registry_uri}"
sinatra_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${remote_dir}/sinatra")/g" \
  -e "s/SEDregionSED/${region}/g" \
  -e "s/SEDdocker_repository_uriSED/$(escape "${sinatra_docker_repository_uri}")/g" \
  -e "s/SEDdocker_img_nmSED/$(escape "${SINATRA_DOCKER_IMG_NM}")/g" \
  -e "s/SEDdocker_img_tagSED/${SINATRA_DOCKER_IMG_TAG}/g" \
  "${CONTAINERS_DIR}"/image-remove.sh > "${temporary_dir}"/sinatra/sinatra-remove.sh  

echo 'sinatra-remove.sh ready.'        

scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/sinatra \
  "${LIBRARY_DIR}"/dockerlib.sh \
  "${LIBRARY_DIR}"/ecr.sh \
  "${temporary_dir}"/sinatra/sinatra-remove.sh     

echo 'Deleting Sinatra image and ECR repository ...'
                                
ssh_run_remote_command_as_root "chmod -R +x ${remote_dir} && ${remote_dir}/sinatra/sinatra-remove.sh" \
  "${private_key_file}" \
  "${eip}" \
  "${ssh_port}" \
  "${user_nm}" \
  "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Sinatra image and ECR repository successfully deleted.' ||
  {
     echo 'ERROR: deleting Sinatra.'
     exit 1   
  } 

echo

#
# Redis
#

echo 'Provisioning Redis scripts ...'

mkdir -p "${temporary_dir}"/redis

ssh_run_remote_command "mkdir -p ${remote_dir}/redis" \
  "${private_key_file}" \
  "${eip}" \
  "${ssh_port}" \
  "${user_nm}"

ecr_get_repostory_uri "${REDIS_DOCKER_IMG_NM}" "${registry_uri}"
redis_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${remote_dir}/redis")/g" \
  -e "s/SEDregionSED/${region}/g" \
  -e "s/SEDdocker_repository_uriSED/$(escape "${redis_docker_repository_uri}")/g" \
  -e "s/SEDdocker_img_nmSED/$(escape "${REDIS_DOCKER_IMG_NM}")/g" \
  -e "s/SEDdocker_img_tagSED/${REDIS_DOCKER_IMG_TAG}/g" \
   "${CONTAINERS_DIR}"/image-remove.sh > "${temporary_dir}"/redis/redis-remove.sh  

echo 'redis-remove.sh ready.'        

scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/redis \
  "${LIBRARY_DIR}"/dockerlib.sh \
  "${LIBRARY_DIR}"/ecr.sh \
  "${temporary_dir}"/redis/redis-remove.sh     

echo 'Deleting Redis image and ECR repository ...'
                                
ssh_run_remote_command_as_root "chmod -R +x ${remote_dir} && ${remote_dir}/redis/redis-remove.sh" \
  "${private_key_file}" \
  "${eip}" \
  "${ssh_port}" \
  "${user_nm}" \
  "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Redis image and ECR repository successfully deleted.' ||
  {
     echo 'ERROR: deleting Redis.'
     exit 1   
  } 

echo

#
# Ruby
#

echo 'Provisioning Ruby scripts ...'

mkdir -p "${temporary_dir}"/ruby

ssh_run_remote_command "mkdir -p ${remote_dir}/ruby" \
  "${private_key_file}" \
  "${eip}" \
  "${ssh_port}" \
  "${user_nm}"

ecr_get_repostory_uri "${RUBY_DOCKER_IMG_NM}" "${registry_uri}"
ruby_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${remote_dir}/ruby")/g" \
  -e "s/SEDregionSED/${region}/g" \
  -e "s/SEDdocker_repository_uriSED/$(escape "${ruby_docker_repository_uri}")/g" \
  -e "s/SEDdocker_img_nmSED/$(escape "${RUBY_DOCKER_IMG_NM}")/g" \
  -e "s/SEDdocker_img_tagSED/${RUBY_DOCKER_IMG_TAG}/g" \
    "${CONTAINERS_DIR}"/image-remove.sh > "${temporary_dir}"/ruby/ruby-remove.sh  

echo 'ruby-remove.sh ready.'        

scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/ruby \
  "${LIBRARY_DIR}"/dockerlib.sh \
  "${LIBRARY_DIR}"/ecr.sh \
  "${temporary_dir}"/ruby/ruby-remove.sh     

echo 'Deleting Ruby image and ECR repository ...'
                                 
ssh_run_remote_command_as_root "chmod -R +x ${remote_dir} && ${remote_dir}/ruby/ruby-remove.sh" \
  "${private_key_file}" \
  "${eip}" \
  "${ssh_port}" \
  "${user_nm}" \
  "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Ruby image and ECR repository successfully deleted.' ||
  {
     echo 'ERROR: deleting Ruby.'
     exit 1   
  }

echo

#
# Centos
#

echo 'Provisioning Centos scripts ...'

mkdir -p "${temporary_dir}"/centos

ssh_run_remote_command "mkdir -p ${remote_dir}/centos" \
  "${private_key_file}" \
  "${eip}" \
  "${ssh_port}" \
  "${user_nm}"

ecr_get_repostory_uri "${CENTOS_DOCKER_IMG_NM}" "${registry_uri}"
centos_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${remote_dir}/centos")/g" \
  -e "s/SEDregionSED/${region}/g" \
  -e "s/SEDdocker_repository_uriSED/$(escape "${centos_docker_repository_uri}")/g" \
  -e "s/SEDdocker_img_nmSED/$(escape "${CENTOS_DOCKER_IMG_NM}")/g" \
  -e "s/SEDdocker_img_tagSED/${CENTOS_DOCKER_IMG_TAG}/g" \
    "${CONTAINERS_DIR}"/image-remove.sh > "${temporary_dir}"/centos/centos-remove.sh           

echo 'centos-remove.sh ready.' 

scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/centos \
  "${LIBRARY_DIR}"/dockerlib.sh \
  "${LIBRARY_DIR}"/ecr.sh \
  "${temporary_dir}"/centos/centos-remove.sh 

echo 'Deleting Centos image and ECR repository ...'
                               
ssh_run_remote_command_as_root "chmod -R +x ${remote_dir} && ${remote_dir}/centos/centos-remove.sh" \
  "${private_key_file}" \
  "${eip}" \
  "${ssh_port}" \
  "${user_nm}" \
  "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Centos image and ECR repository successfully deleted.' ||
  {    
     echo 'ERROR: deleting Centos.'
     exit 1 
  }

echo         
                
ssh_run_remote_command "rm -rf ${remote_dir:?}" \
  "${private_key_file}" \
  "${eip}" \
  "${ssh_port}" \
  "${user_nm}"

#
# Permissions.
#

check_role_has_permission_policy_attached "${role_nm}" "${ECR_POLICY_NM}"
is_permission_policy_associated="${__RESULT}"

if [[ 'true' == "${is_permission_policy_associated}" ]]
then
  echo 'Detaching permission policy from role ...'

  detach_permission_policy_from_role "${role_nm}" "${ECR_POLICY_NM}"

  echo 'Permission policy detached.'
else
  echo 'WARN: permission policy already detached from the role.'
fi 

## 
## Firewall.
##

check_access_is_granted "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'true' == "${is_granted}" ]]
then
  revoke_access_from_cidr "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}" 

  echo "Access revoked on ${ssh_port} tcp 0.0.0.0/0."
else
  echo "WARN: access already revoked ${ssh_port} tcp 0.0.0.0/0."
fi

echo 'Revoked SSH access to the box.'      
echo

# Removing old files
# shellcheck disable=SC2115
rm -rf  "${temporary_dir:?}"

