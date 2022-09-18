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

get_user_name
user_nm="${__RESULT}"
SCRIPTS_DIR=/home/"${user_nm}"/script
logfile_nm=ecr.log

####
STEP "ECR registry"
####

# Jumpbox where the images are built.
get_instance_name 'admin'
admin_instance_nm="${__RESULT}"
get_instance_id "${admin_instance_nm}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: admin jumpbox not found.'
fi

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${admin_instance_nm}"
   instance_st="${__RESULT}"
   
   if [[ 'running' == "${instance_st}" ]]
   then
      echo "* admin jumpbox ready (${instance_st})."
   else
      echo "* WARN: admin jumpbox not ready. (${instance_st})."
   fi
fi
 
get_public_ip_address_associated_with_instance "${admin_instance_nm}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo '* WARN: Admin IP address not found.'
else
   echo "* admin IP address: ${eip}."
fi

get_security_group_name 'admin'
admin_sgp_nm="${__RESULT}"
get_security_group_id "${admin_sgp_nm}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: admin security group not found.' 
else
   echo "* admin security group ID: ${sgp_id}."
fi

# Removing old files
# shellcheck disable=SC2115
tmp_dir="${TMP_DIR}"/ecr
rm -rf  "${tmp_dir:?}"
mkdir -p "${tmp_dir}"

echo


if [[ -n "${instance_id}" && 'running' == "${instance_st}" ]]
then
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

   #
   # Permissions.
   #

   get_role_name 'admin'
   admin_role_nm="${__RESULT}"
   check_role_has_permission_policy_attached "${admin_role_nm}" "${ECR_POLICY_NM}"
   is_permission_policy_associated="${__RESULT}"

   if [[ 'false' == "${is_permission_policy_associated}" ]]
   then
      echo 'Attaching permission policy to the role ...'

      attach_permission_policy_to_role "${admin_role_nm}" "${ECR_POLICY_NM}"
      
      echo 'Permission policy associated to the role.' 
   else
      echo 'WARN: permission policy already associated to the role.'
   fi   

   get_keypair_name 'admin'
   admin_keypair_nm="${__RESULT}"
   private_key_file="${ACCESS_DIR}"/"${admin_keypair_nm}" 
   wait_ssh_started "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}"
  
   # Prepare the scripts to run on the server.

   ssh_run_remote_command "rm -rf ${SCRIPTS_DIR:?}" \
       "${private_key_file}" \
       "${eip}" \
       "${ssh_port}" \
       "${user_nm}"

   #
   # Jenkins
   #

   echo 'Provisioning Jenkins scripts ...'

   mkdir -p "${tmp_dir}"/jenkins

   ssh_run_remote_command "mkdir -p ${SCRIPTS_DIR}/jenkins" \
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

   sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}/jenkins")/g" \
       -e "s/SEDregionSED/${region}/g" \
       -e "s/SEDdocker_repository_uriSED/$(escape "${jenkins_docker_repository_uri}")/g" \
       -e "s/SEDdocker_img_nmSED/$(escape "${JENKINS_DOCKER_IMG_NM}")/g" \
       -e "s/SEDdocker_img_tagSED/${JENKINS_DOCKER_IMG_TAG}/g" \
          "${CONTAINERS_DIR}"/image-remove.sh > "${tmp_dir}"/jenkins/jenkins-remove.sh    
     
   echo 'jenkins-remove.sh ready.'        
     
   scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${SCRIPTS_DIR}"/jenkins \
       "${LIBRARY_DIR}"/dockerlib.sh \
       "${LIBRARY_DIR}"/ecr.sh \
       "${tmp_dir}"/jenkins/jenkins-remove.sh     

   echo 'Deleting Jenkins image and ECR repository ...'

   get_user_password
   user_pwd="${__RESULT}"
                                         
   ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR} && ${SCRIPTS_DIR}/jenkins/jenkins-remove.sh" \
       "${private_key_file}" \
       "${eip}" \
       "${ssh_port}" \
       "${user_nm}" \
       "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Jenkins image and ECR repository successfully deleted.' ||
       {
          echo 'WARN: the role may not have been associated to the profile yet.'
          echo 'Let''s wait a bit and check again (first time).' 
      
          wait 180  
      
          echo 'Let''s try now.' 
    
          ssh_run_remote_command_as_root "${SCRIPTS_DIR}/jenkins/jenkins-remove.sh" \
             "${private_key_file}" \
             "${eip}" \
             "${ssh_port}" \
             "${user_nm}" \
             "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Jenkins image and ECR repository successfully deleted.' ||
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

   mkdir -p "${tmp_dir}"/nginx


   ssh_run_remote_command "mkdir -p ${SCRIPTS_DIR}/nginx" \
       "${private_key_file}" \
       "${eip}" \
       "${ssh_port}" \
       "${user_nm}"

   ecr_get_repostory_uri "${NGINX_DOCKER_IMG_NM}" "${registry_uri}"
   nginx_docker_repository_uri="${__RESULT}"

   sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}/nginx")/g" \
       -e "s/SEDregionSED/${region}/g" \
       -e "s/SEDdocker_repository_uriSED/$(escape "${nginx_docker_repository_uri}")/g" \
       -e "s/SEDdocker_img_nmSED/$(escape "${NGINX_DOCKER_IMG_NM}")/g" \
       -e "s/SEDdocker_img_tagSED/${NGINX_DOCKER_IMG_TAG}/g" \
          "${CONTAINERS_DIR}"/image-remove.sh > "${tmp_dir}"/nginx/nginx-remove.sh  
       
   echo 'nginx-remove.sh ready.'        
     
   scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${SCRIPTS_DIR}"/nginx \
       "${LIBRARY_DIR}"/dockerlib.sh \
       "${LIBRARY_DIR}"/ecr.sh \
       "${tmp_dir}"/nginx/nginx-remove.sh     

   echo 'Deleting Nginx image and ECR repository ...'
                                     
   ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR} && ${SCRIPTS_DIR}/nginx/nginx-remove.sh" \
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

   mkdir -p "${tmp_dir}"/sinatra

   ssh_run_remote_command "mkdir -p ${SCRIPTS_DIR}/sinatra" \
       "${private_key_file}" \
       "${eip}" \
       "${ssh_port}" \
       "${user_nm}"

   ecr_get_repostory_uri "${SINATRA_DOCKER_IMG_NM}" "${registry_uri}"
   sinatra_docker_repository_uri="${__RESULT}"

   sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}/sinatra")/g" \
       -e "s/SEDregionSED/${region}/g" \
       -e "s/SEDdocker_repository_uriSED/$(escape "${sinatra_docker_repository_uri}")/g" \
       -e "s/SEDdocker_img_nmSED/$(escape "${SINATRA_DOCKER_IMG_NM}")/g" \
       -e "s/SEDdocker_img_tagSED/${SINATRA_DOCKER_IMG_TAG}/g" \
       "${CONTAINERS_DIR}"/image-remove.sh > "${tmp_dir}"/sinatra/sinatra-remove.sh  
       
   echo 'sinatra-remove.sh ready.'        
     
   scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${SCRIPTS_DIR}"/sinatra \
       "${LIBRARY_DIR}"/dockerlib.sh \
       "${LIBRARY_DIR}"/ecr.sh \
       "${tmp_dir}"/sinatra/sinatra-remove.sh     

   echo 'Deleting Sinatra image and ECR repository ...'
                                        
   ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR} && ${SCRIPTS_DIR}/sinatra/sinatra-remove.sh" \
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

   mkdir -p "${tmp_dir}"/redis

   ssh_run_remote_command "mkdir -p ${SCRIPTS_DIR}/redis" \
       "${private_key_file}" \
       "${eip}" \
       "${ssh_port}" \
       "${user_nm}"

   ecr_get_repostory_uri "${REDIS_DOCKER_IMG_NM}" "${registry_uri}"
   redis_docker_repository_uri="${__RESULT}"

   sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}/redis")/g" \
       -e "s/SEDregionSED/${region}/g" \
       -e "s/SEDdocker_repository_uriSED/$(escape "${redis_docker_repository_uri}")/g" \
       -e "s/SEDdocker_img_nmSED/$(escape "${REDIS_DOCKER_IMG_NM}")/g" \
       -e "s/SEDdocker_img_tagSED/${REDIS_DOCKER_IMG_TAG}/g" \
         "${CONTAINERS_DIR}"/image-remove.sh > "${tmp_dir}"/redis/redis-remove.sh  
       
   echo 'redis-remove.sh ready.'        
     
   scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${SCRIPTS_DIR}"/redis \
       "${LIBRARY_DIR}"/dockerlib.sh \
       "${LIBRARY_DIR}"/ecr.sh \
       "${tmp_dir}"/redis/redis-remove.sh     

   echo 'Deleting Redis image and ECR repository ...'
                                        
   ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR} && ${SCRIPTS_DIR}/redis/redis-remove.sh" \
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

   mkdir -p "${tmp_dir}"/ruby

   ssh_run_remote_command "mkdir -p ${SCRIPTS_DIR}/ruby" \
       "${private_key_file}" \
       "${eip}" \
       "${ssh_port}" \
       "${user_nm}"

   ecr_get_repostory_uri "${RUBY_DOCKER_IMG_NM}" "${registry_uri}"
   ruby_docker_repository_uri="${__RESULT}"

   sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}/ruby")/g" \
       -e "s/SEDregionSED/${region}/g" \
       -e "s/SEDdocker_repository_uriSED/$(escape "${ruby_docker_repository_uri}")/g" \
       -e "s/SEDdocker_img_nmSED/$(escape "${RUBY_DOCKER_IMG_NM}")/g" \
       -e "s/SEDdocker_img_tagSED/${RUBY_DOCKER_IMG_TAG}/g" \
          "${CONTAINERS_DIR}"/image-remove.sh > "${tmp_dir}"/ruby/ruby-remove.sh  
       
   echo 'ruby-remove.sh ready.'        
     
   scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${SCRIPTS_DIR}"/ruby \
       "${LIBRARY_DIR}"/dockerlib.sh \
       "${LIBRARY_DIR}"/ecr.sh \
       "${tmp_dir}"/ruby/ruby-remove.sh     

   echo 'Deleting Ruby image and ECR repository ...'
                                         
   ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR} && ${SCRIPTS_DIR}/ruby/ruby-remove.sh" \
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

   mkdir -p "${tmp_dir}"/centos

   ssh_run_remote_command "mkdir -p ${SCRIPTS_DIR}/centos" \
       "${private_key_file}" \
       "${eip}" \
       "${ssh_port}" \
       "${user_nm}"

   ecr_get_repostory_uri "${CENTOS_DOCKER_IMG_NM}" "${registry_uri}"
   centos_docker_repository_uri="${__RESULT}"

   sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}/centos")/g" \
       -e "s/SEDregionSED/${region}/g" \
       -e "s/SEDdocker_repository_uriSED/$(escape "${centos_docker_repository_uri}")/g" \
       -e "s/SEDdocker_img_nmSED/$(escape "${CENTOS_DOCKER_IMG_NM}")/g" \
       -e "s/SEDdocker_img_tagSED/${CENTOS_DOCKER_IMG_TAG}/g" \
          "${CONTAINERS_DIR}"/image-remove.sh > "${tmp_dir}"/centos/centos-remove.sh           
       
   echo 'centos-remove.sh ready.' 
    
   scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${SCRIPTS_DIR}"/centos \
       "${LIBRARY_DIR}"/dockerlib.sh \
       "${LIBRARY_DIR}"/ecr.sh \
       "${tmp_dir}"/centos/centos-remove.sh 
    
   echo 'Deleting Centos image and ECR repository ...'
                                       
   ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR} && ${SCRIPTS_DIR}/centos/centos-remove.sh" \
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
                        
   ssh_run_remote_command "rm -rf ${SCRIPTS_DIR:?}" \
       "${private_key_file}" \
       "${eip}" \
       "${ssh_port}" \
       "${user_nm}"
    
   #
   # Permissions.
   #

   check_role_has_permission_policy_attached "${admin_role_nm}" "${ECR_POLICY_NM}"
   is_permission_policy_associated="${__RESULT}"

   if [[ 'true' == "${is_permission_policy_associated}" ]]
   then
      echo 'Detaching permission policy from role ...'
   
      detach_permission_policy_from_role "${admin_role_nm}" "${ECR_POLICY_NM}"
      
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
   rm -rf  "${tmp_dir:?}"
fi
