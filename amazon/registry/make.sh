#!/bin/bash

# shellcheck disable=SC2015

#####################################################################
# The script builds on the Admin jumpbox and push to ECR the base 
# Docker images for following containers:
#
#   Centos operating system.
#   Ruby 
#   Jenkins
#   Sinatra web 
#   Redis database
#   Nginx web
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

get_public_ip_address_associated_with_instance "${instance_nm}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo '* ERROR: admin jumpbox IP address not found.'
   exit 1
else
   echo "* admin jumpbox IP address: ${eip}."
fi

get_security_group_name "${instance_key}"
admin_sgp_nm="${__RESULT}"
get_security_group_id "${admin_sgp_nm}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* ERROR: admin jumpbox security group not found.'
   exit 1
else
   echo "* admin jumpbox security group ID: ${sgp_id}."
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

#
# Permissions.
#

get_role_name "${instance_key}"
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

get_keypair_name "${instance_key}"
admin_keypair_nm="${__RESULT}"
private_key_file="${ACCESS_DIR}"/"${admin_keypair_nm}" 
wait_ssh_started "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}"

get_user_name
user_nm="${__RESULT}"
remote_dir=/home/"${user_nm}"/script
    
# Prepare the scripts to run on the server.

ssh_run_remote_command "rm -rf ${remote_dir:?}" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"

#
# Centos
#

echo 'Provisioning Centos scripts ...'

mkdir -p "${temporary_dir}"/centos

ssh_run_remote_command "mkdir -p ${remote_dir}/centos/dockerctx" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"

get_region_name
region="${__RESULT}"
ecr_get_registry_uri "${region}"
registry_uri="${__RESULT}"
ecr_get_repostory_uri "${CENTOS_DOCKER_IMG_NM}" "${registry_uri}"
centos_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${remote_dir}/centos")/g" \
    -e "s/SEDimage_descSED/centos/g" \
    -e "s/SEDregionSED/${region}/g" \
    -e "s/SEDdocker_ctxSED/$(escape "${remote_dir}"/centos/dockerctx)/g" \
    -e "s/SEDdocker_repository_uriSED/$(escape "${centos_docker_repository_uri}")/g" \
    -e "s/SEDdocker_img_nmSED/$(escape "${CENTOS_DOCKER_IMG_NM}")/g" \
    -e "s/SEDdocker_img_tagSED/${CENTOS_DOCKER_IMG_TAG}/g" \
       "${CONTAINERS_DIR}"/image-build.sh > "${temporary_dir}"/centos/centos-build.sh  
      
echo 'centos-build.sh ready.' 
    
sed -e "s/SEDbase_centos_docker_repository_uriSED/${BASE_CENTOS_DOCKER_IMG_NM}/g" \
    -e "s/SEDbase_centos_docker_img_tagSED/${BASE_CENTOS_DOCKER_IMG_TAG}/g" \
       "${CONTAINERS_DIR}"/centos/Dockerfile > "${temporary_dir}"/centos/Dockerfile    
    
echo 'Dockerfile ready.'     

scp_upload_file "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/centos/dockerctx \
    "${temporary_dir}"/centos/Dockerfile   
    
scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/centos \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${temporary_dir}"/centos/centos-build.sh 
    
echo 'Building Centos image ...'

get_user_password
user_pwd="${__RESULT}"
           
# build Centos images in the box and send it to ECR.                             
ssh_run_remote_command_as_root "chmod -R +x ${remote_dir} && ${remote_dir}/centos/centos-build.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Centos image successfully built.' ||
    {    
       echo 'WARN: the role may not have been associated to the profile yet.'
       echo 'Let''s wait a bit and check again (first time).' 
      
       wait 180  
      
       echo 'Let''s try now.' 
    
       ssh_run_remote_command_as_root "${remote_dir}/centos/centos-build.sh" \
          "${private_key_file}" \
          "${eip}" \
          "${ssh_port}" \
          "${user_nm}" \
          "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Centos image successfully built.' ||
          {
              echo 'ERROR: the problem persists after 3 minutes.'
              exit 1          
          }
    }
    
echo  

#
# Ruby
#

echo 'Provisioning Ruby scripts ...'

mkdir -p "${temporary_dir}"/ruby

ssh_run_remote_command "mkdir -p ${remote_dir}/ruby/dockerctx" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"

ecr_get_repostory_uri "${RUBY_DOCKER_IMG_NM}" "${registry_uri}"
ruby_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${remote_dir}/ruby")/g" \
    -e "s/SEDimage_descSED/ruby/g" \
    -e "s/SEDregionSED/${region}/g" \
    -e "s/SEDdocker_ctxSED/$(escape "${remote_dir}"/ruby/dockerctx)/g" \
    -e "s/SEDdocker_repository_uriSED/$(escape "${ruby_docker_repository_uri}")/g" \
    -e "s/SEDdocker_img_nmSED/$(escape "${RUBY_DOCKER_IMG_NM}")/g" \
    -e "s/SEDdocker_img_tagSED/${RUBY_DOCKER_IMG_TAG}/g" \
       "${CONTAINERS_DIR}"/image-build.sh > "${temporary_dir}"/ruby/ruby-build.sh  
    
echo 'ruby-build.sh ready.' 

sed -e "s/SEDruby_docker_repository_uriSED/$(escape "${centos_docker_repository_uri}")/g" \
    -e "s/SEDruby_docker_img_tagSED/${CENTOS_DOCKER_IMG_TAG}/g" \
       "${CONTAINERS_DIR}"/ruby/Dockerfile > "${temporary_dir}"/ruby/Dockerfile
       
echo 'ruby Dockerfile ready.'        

scp_upload_file "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/ruby/dockerctx \
    "${temporary_dir}"/ruby/Dockerfile
     
scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/ruby \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${temporary_dir}"/ruby/ruby-build.sh     

echo 'Building Ruby image ...'
            
# build Ruby images in the box and send it to ECR.                             
ssh_run_remote_command_as_root "chmod -R +x ${remote_dir} && ${remote_dir}/ruby/ruby-build.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Ruby image successfully built.' ||
    {
        echo 'ERROR: building Ruby.'
        exit 1   
    }
    
echo   

#
# Jenkins
#

echo 'Provisioning Jenkins scripts ...'

mkdir -p "${temporary_dir}"/jenkins

ssh_run_remote_command "mkdir -p ${remote_dir}/jenkins/dockerctx" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"

ecr_get_repostory_uri "${JENKINS_DOCKER_IMG_NM}" "${registry_uri}"
jenkins_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${remote_dir}/jenkins")/g" \
    -e "s/SEDimage_descSED/jenkins/g" \
    -e "s/SEDregionSED/${region}/g" \
    -e "s/SEDdocker_ctxSED/$(escape "${remote_dir}"/jenkins/dockerctx)/g" \
    -e "s/SEDdocker_repository_uriSED/$(escape "${jenkins_docker_repository_uri}")/g" \
    -e "s/SEDdocker_img_nmSED/$(escape "${JENKINS_DOCKER_IMG_NM}")/g" \
    -e "s/SEDdocker_img_tagSED/${JENKINS_DOCKER_IMG_TAG}/g" \
       "${CONTAINERS_DIR}"/image-build.sh > "${temporary_dir}"/jenkins/jenkins-build.sh       
     
echo 'jenkins-build.sh ready.'

sed -e "s/SEDbase_jenkins_docker_repository_uriSED/$(escape "${BASE_JENKINS_DOCKER_IMG_NM}")/g" \
    -e "s/SEDbase_jenkins_docker_img_tagSED/${BASE_JENKINS_DOCKER_IMG_TAG}/g" \
       "${CONTAINERS_DIR}"/jenkins/Dockerfile > "${temporary_dir}"/jenkins/Dockerfile   
       
echo 'Dockerfile ready.'        
   
scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/jenkins/dockerctx \
    "${temporary_dir}"/jenkins/Dockerfile \
    "${CONTAINERS_DIR}"/jenkins/plugins.txt  
    
scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/jenkins \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${temporary_dir}"/jenkins/jenkins-build.sh         

echo 'Building Jenkins image ...'

ssh_run_remote_command_as_root "chmod -R +x ${remote_dir} && ${remote_dir}/jenkins/jenkins-build.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Jenkins image successfully built.' ||
    {
        echo 'ERROR: building Jenkins.'
        exit 1   
    } 
    
echo

#
# Nginx
#

echo 'Provisioning Nginx scripts ...'

mkdir -p "${temporary_dir}"/nginx

ssh_run_remote_command "mkdir -p ${remote_dir}/nginx/dockerctx" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"

ecr_get_repostory_uri "${NGINX_DOCKER_IMG_NM}" "${registry_uri}"
nginx_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${remote_dir}/nginx")/g" \
    -e "s/SEDimage_descSED/nginx/g" \
    -e "s/SEDregionSED/${region}/g" \
    -e "s/SEDdocker_ctxSED/$(escape "${remote_dir}"/nginx/dockerctx)/g" \
    -e "s/SEDdocker_repository_uriSED/$(escape "${nginx_docker_repository_uri}")/g" \
    -e "s/SEDdocker_img_nmSED/$(escape "${NGINX_DOCKER_IMG_NM}")/g" \
    -e "s/SEDdocker_img_tagSED/${NGINX_DOCKER_IMG_TAG}/g" \
       "${CONTAINERS_DIR}"/image-build.sh > "${temporary_dir}"/nginx/nginx-build.sh  
                     
echo 'nginx-build.sh ready.' 

get_application_port 'nginx'
nginx_port="${__RESULT}" 

# The Nginx image is built from the base Centos image.
sed -e "s/SEDrepository_uriSED/$(escape "${centos_docker_repository_uri}")/g" \
    -e "s/SEDimg_tagSED/${CENTOS_DOCKER_IMG_TAG}/g" \
    -e "s/SEDnginx_container_volume_dirSED/$(escape "${NGINX_CONTAINER_VOLUME_DIR}")/g" \
    -e "s/SEDhttp_portSED/${nginx_port}/g" \
       "${CONTAINERS_DIR}"/nginx/Dockerfile > "${temporary_dir}"/nginx/Dockerfile

echo 'Dockerfile ready.'

sed -e "s/SEDnginx_container_volume_dirSED/$(escape "${NGINX_CONTAINER_VOLUME_DIR}")/g" \
       "${CONTAINERS_DIR}"/nginx/global.conf > "${temporary_dir}"/nginx/global.conf
    
echo 'global.conf ready.'  

scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/nginx/dockerctx \
    "${temporary_dir}"/nginx/Dockerfile \
    "${temporary_dir}"/nginx/global.conf \
    "${CONTAINERS_DIR}"/nginx/nginx.conf
    
scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/nginx \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${temporary_dir}"/nginx/nginx-build.sh 

echo 'Building Nginx image ...'
                                        
ssh_run_remote_command_as_root "chmod -R +x ${remote_dir} && ${remote_dir}/nginx/nginx-build.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Nginx image successfully built.' ||
    {
        echo 'ERROR: building Nginx.'
        exit 1   
    }   
    
echo 

#
# Sinatra
#

echo 'Provisioning Sinatra scripts ...'

mkdir -p "${temporary_dir}"/sinatra

ssh_run_remote_command "mkdir -p ${remote_dir}/sinatra/dockerctx" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"

ecr_get_repostory_uri "${SINATRA_DOCKER_IMG_NM}" "${registry_uri}"
sinatra_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${remote_dir}/sinatra")/g" \
    -e "s/SEDimage_descSED/sinatra/g" \
    -e "s/SEDregionSED/${region}/g" \
    -e "s/SEDdocker_ctxSED/$(escape "${remote_dir}"/sinatra/dockerctx)/g" \
    -e "s/SEDdocker_repository_uriSED/$(escape "${sinatra_docker_repository_uri}")/g" \
    -e "s/SEDdocker_img_nmSED/$(escape "${SINATRA_DOCKER_IMG_NM}")/g" \
    -e "s/SEDdocker_img_tagSED/${SINATRA_DOCKER_IMG_TAG}/g" \
       "${CONTAINERS_DIR}"/image-build.sh > "${temporary_dir}"/sinatra/sinatra-build.sh  
                                       
echo 'sinatra-build.sh ready.' 

get_application_port 'sinatra'
sinatra_port="${__RESULT}" 

# The Sinatra image is built from the base Ruby image.
sed -e "s/SEDrepository_uriSED/$(escape "${ruby_docker_repository_uri}")/g" \
    -e "s/SEDimg_tagSED/${RUBY_DOCKER_IMG_TAG}/g" \
    -e "s/SEDcontainer_volume_dirSED/$(escape "${SINATRA_DOCKER_CONTAINER_VOLUME_DIR}")/g" \
    -e "s/SEDhttp_portSED/${sinatra_port}/g" \
       "${CONTAINERS_DIR}"/sinatra/Dockerfile > "${temporary_dir}"/sinatra/Dockerfile

echo 'Dockerfile ready.'

scp_upload_file "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/sinatra/dockerctx \
    "${temporary_dir}"/sinatra/Dockerfile 

scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/sinatra \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${temporary_dir}"/sinatra/sinatra-build.sh  
    
echo 'Building Sinatra image ...'
            
# build Sinatra images in the box and send it to ECR.                             
ssh_run_remote_command_as_root "chmod -R +x ${remote_dir} && ${remote_dir}/sinatra/sinatra-build.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Sinatra image successfully built.' ||
    {
        echo 'ERROR: building Sinatra.'
        exit 1   
    }    
 
echo 
   
#
# Redis
#   

echo 'Provisioning Redis scripts ...'

mkdir -p "${temporary_dir}"/redis

ssh_run_remote_command "mkdir -p ${remote_dir}/redis/dockerctx" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"

ecr_get_repostory_uri "${REDIS_DOCKER_IMG_NM}" "${registry_uri}"
redis_docker_repository_uri="${__RESULT}"
get_application_port 'redis'
redis_port="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${remote_dir}"/redis)/g" \
    -e "s/SEDimage_descSED/redis/g" \
    -e "s/SEDregionSED/${region}/g" \
    -e "s/SEDdocker_ctxSED/$(escape "${remote_dir}"/redis/dockerctx)/g" \
    -e "s/SEDdocker_repository_uriSED/$(escape "${redis_docker_repository_uri}")/g" \
    -e "s/SEDdocker_img_nmSED/$(escape "${REDIS_DOCKER_IMG_NM}")/g" \
    -e "s/SEDdocker_img_tagSED/${REDIS_DOCKER_IMG_TAG}/g" \
    -e "s/SEDip_portSED/${redis_port}/g" \
       "${CONTAINERS_DIR}"/image-build.sh > "${temporary_dir}"/redis-build.sh  
 
echo 'redis-build.sh ready.'  

# The Redis image is built from the Centos image.
ecr_get_repostory_uri "${CENTOS_DOCKER_IMG_NM}" "${registry_uri}"
centos_docker_repository_uri="${__RESULT}"

sed -e "s/SEDrepository_uriSED/$(escape "${centos_docker_repository_uri}")/g" \
    -e "s/SEDimg_tagSED/${CENTOS_DOCKER_IMG_TAG}/g" \
    -e "s/SEDhttp_portSED/${redis_port}/g" \
       "${CONTAINERS_DIR}"/redis/Dockerfile > "${temporary_dir}"/Dockerfile

echo 'Dockerfile ready.'
   
scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/redis/dockerctx \
    "${temporary_dir}"/Dockerfile \
    "${CONTAINERS_DIR}"/redis/redis.conf
    
scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/redis \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${temporary_dir}"/redis-build.sh

ssh_run_remote_command_as_root "chmod -R +x ${remote_dir}"/redis \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" 

echo 'Building Redis image ...'
            
# build Redis images in the box and send it to ECR.                             
ssh_run_remote_command_as_root "chmod -R +x ${remote_dir} && ${remote_dir}/redis/redis-build.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Redis image successfully built.' ||
    {
        echo 'ERROR: building Redis.'
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
rm -rf  "${temporary_dir:?}"

