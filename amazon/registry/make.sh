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

get_user_name
user_nm="${__RESULT}"
SCRIPTS_DIR=/home/"${user_nm}"/script
logfile_nm=ecr.log

####
STEP "ECR registry"
####

#
# Get the configuration values from the file ec2_consts.json
#

get_instance_name 'admin'
admin_instance_nm="${__RESULT}"

# Jumpbox where the images are built.
get_instance_id "${admin_instance_nm}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* ERROR: admin jumpbox not found.'
   exit 1
fi

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${admin_instance_nm}"
   instance_st="${__RESULT}"
   
   if [[ 'running' == "${instance_st}" ]]
   then
      echo "* admin jumpbox ready (${instance_st})."
   else
      echo "* ERROR: admin jumpbox not ready. (${instance_st})."
      
      exit 1
   fi
fi

get_public_ip_address_associated_with_instance "${admin_instance_nm}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo '* ERROR: admin jumpbox IP address not found.'
   exit 1
else
   echo "* admin jumpbox IP address: ${eip}."
fi

get_security_group_name 'admin'
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

# Removing old files
# shellcheck disable=SC2115
tmp_dir="${TMP_DIR}"/ecr
rm -rf  "${tmp_dir:?}"
mkdir -p "${tmp_dir}"

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
# Centos
#

echo 'Provisioning Centos scripts ...'

mkdir -p "${tmp_dir}"/centos

ssh_run_remote_command "mkdir -p ${SCRIPTS_DIR}/centos/dockerctx" \
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

sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}/centos")/g" \
    -e "s/SEDimage_descSED/centos/g" \
    -e "s/SEDregionSED/${region}/g" \
    -e "s/SEDdocker_ctxSED/$(escape "${SCRIPTS_DIR}"/centos/dockerctx)/g" \
    -e "s/SEDdocker_repository_uriSED/$(escape "${centos_docker_repository_uri}")/g" \
    -e "s/SEDdocker_img_nmSED/$(escape "${CENTOS_DOCKER_IMG_NM}")/g" \
    -e "s/SEDdocker_img_tagSED/${CENTOS_DOCKER_IMG_TAG}/g" \
       "${CONTAINERS_DIR}"/image-build.sh > "${tmp_dir}"/centos/centos-build.sh  
      
echo 'centos-build.sh ready.' 
    
sed -e "s/SEDbase_centos_docker_repository_uriSED/${BASE_CENTOS_DOCKER_IMG_NM}/g" \
    -e "s/SEDbase_centos_docker_img_tagSED/${BASE_CENTOS_DOCKER_IMG_TAG}/g" \
       "${CONTAINERS_DIR}"/centos/Dockerfile > "${tmp_dir}"/centos/Dockerfile    
    
echo 'Dockerfile ready.'     

scp_upload_file "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${SCRIPTS_DIR}"/centos/dockerctx \
    "${tmp_dir}"/centos/Dockerfile   
    
scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${SCRIPTS_DIR}"/centos \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${tmp_dir}"/centos/centos-build.sh 
    
echo 'Building Centos image ...'

get_user_password
user_pwd="${__RESULT}"
           
# build Centos images in the box and send it to ECR.                             
ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR} && ${SCRIPTS_DIR}/centos/centos-build.sh" \
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
    
       ssh_run_remote_command_as_root "${SCRIPTS_DIR}/centos/centos-build.sh" \
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

mkdir -p "${tmp_dir}"/ruby

ssh_run_remote_command "mkdir -p ${SCRIPTS_DIR}/ruby/dockerctx" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"

ecr_get_repostory_uri "${RUBY_DOCKER_IMG_NM}" "${registry_uri}"
ruby_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}/ruby")/g" \
    -e "s/SEDimage_descSED/ruby/g" \
    -e "s/SEDregionSED/${region}/g" \
    -e "s/SEDdocker_ctxSED/$(escape "${SCRIPTS_DIR}"/ruby/dockerctx)/g" \
    -e "s/SEDdocker_repository_uriSED/$(escape "${ruby_docker_repository_uri}")/g" \
    -e "s/SEDdocker_img_nmSED/$(escape "${RUBY_DOCKER_IMG_NM}")/g" \
    -e "s/SEDdocker_img_tagSED/${RUBY_DOCKER_IMG_TAG}/g" \
       "${CONTAINERS_DIR}"/image-build.sh > "${tmp_dir}"/ruby/ruby-build.sh  
    
echo 'ruby-build.sh ready.' 

sed -e "s/SEDruby_docker_repository_uriSED/$(escape "${centos_docker_repository_uri}")/g" \
    -e "s/SEDruby_docker_img_tagSED/${CENTOS_DOCKER_IMG_TAG}/g" \
       "${CONTAINERS_DIR}"/ruby/Dockerfile > "${tmp_dir}"/ruby/Dockerfile
       
echo 'ruby Dockerfile ready.'        

scp_upload_file "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${SCRIPTS_DIR}"/ruby/dockerctx \
    "${tmp_dir}"/ruby/Dockerfile
     
scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${SCRIPTS_DIR}"/ruby \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${tmp_dir}"/ruby/ruby-build.sh     

echo 'Building Ruby image ...'
            
# build Ruby images in the box and send it to ECR.                             
ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR} && ${SCRIPTS_DIR}/ruby/ruby-build.sh" \
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

mkdir -p "${tmp_dir}"/jenkins

ssh_run_remote_command "mkdir -p ${SCRIPTS_DIR}/jenkins/dockerctx" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"

ecr_get_repostory_uri "${JENKINS_DOCKER_IMG_NM}" "${registry_uri}"
jenkins_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}/jenkins")/g" \
    -e "s/SEDimage_descSED/jenkins/g" \
    -e "s/SEDregionSED/${region}/g" \
    -e "s/SEDdocker_ctxSED/$(escape "${SCRIPTS_DIR}"/jenkins/dockerctx)/g" \
    -e "s/SEDdocker_repository_uriSED/$(escape "${jenkins_docker_repository_uri}")/g" \
    -e "s/SEDdocker_img_nmSED/$(escape "${JENKINS_DOCKER_IMG_NM}")/g" \
    -e "s/SEDdocker_img_tagSED/${JENKINS_DOCKER_IMG_TAG}/g" \
       "${CONTAINERS_DIR}"/image-build.sh > "${tmp_dir}"/jenkins/jenkins-build.sh       
     
echo 'jenkins-build.sh ready.'

sed -e "s/SEDbase_jenkins_docker_repository_uriSED/$(escape ${BASE_JENKINS_DOCKER_IMG_NM})/g" \
    -e "s/SEDbase_jenkins_docker_img_tagSED/${BASE_JENKINS_DOCKER_IMG_TAG}/g" \
       "${CONTAINERS_DIR}"/jenkins/Dockerfile > "${tmp_dir}"/jenkins/Dockerfile   
       
echo 'Dockerfile ready.'        
   
scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${SCRIPTS_DIR}"/jenkins/dockerctx \
    "${tmp_dir}"/jenkins/Dockerfile \
    "${CONTAINERS_DIR}"/jenkins/plugins.txt  
    
scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${SCRIPTS_DIR}"/jenkins \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${tmp_dir}"/jenkins/jenkins-build.sh         

echo 'Building Jenkins image ...'

ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR} && ${SCRIPTS_DIR}/jenkins/jenkins-build.sh" \
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

mkdir -p "${tmp_dir}"/nginx

ssh_run_remote_command "mkdir -p ${SCRIPTS_DIR}/nginx/dockerctx" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"

ecr_get_repostory_uri "${NGINX_DOCKER_IMG_NM}" "${registry_uri}"
nginx_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}/nginx")/g" \
    -e "s/SEDimage_descSED/nginx/g" \
    -e "s/SEDregionSED/${region}/g" \
    -e "s/SEDdocker_ctxSED/$(escape "${SCRIPTS_DIR}"/nginx/dockerctx)/g" \
    -e "s/SEDdocker_repository_uriSED/$(escape "${nginx_docker_repository_uri}")/g" \
    -e "s/SEDdocker_img_nmSED/$(escape "${NGINX_DOCKER_IMG_NM}")/g" \
    -e "s/SEDdocker_img_tagSED/${NGINX_DOCKER_IMG_TAG}/g" \
       "${CONTAINERS_DIR}"/image-build.sh > "${tmp_dir}"/nginx/nginx-build.sh  
                     
echo 'nginx-build.sh ready.' 

get_application_port 'nginx'
nginx_port="${__RESULT}" 

# The Nginx image is built from the base Centos image.
sed -e "s/SEDrepository_uriSED/$(escape "${centos_docker_repository_uri}")/g" \
    -e "s/SEDimg_tagSED/${CENTOS_DOCKER_IMG_TAG}/g" \
    -e "s/SEDnginx_container_volume_dirSED/$(escape "${NGINX_CONTAINER_VOLUME_DIR}")/g" \
    -e "s/SEDhttp_portSED/${nginx_port}/g" \
       "${CONTAINERS_DIR}"/nginx/Dockerfile > "${tmp_dir}"/nginx/Dockerfile

echo 'Dockerfile ready.'

sed -e "s/SEDnginx_container_volume_dirSED/$(escape "${NGINX_CONTAINER_VOLUME_DIR}")/g" \
       "${CONTAINERS_DIR}"/nginx/global.conf > "${tmp_dir}"/nginx/global.conf
    
echo 'global.conf ready.'  

scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${SCRIPTS_DIR}"/nginx/dockerctx \
    "${tmp_dir}"/nginx/Dockerfile \
    "${tmp_dir}"/nginx/global.conf \
    "${CONTAINERS_DIR}"/nginx/nginx.conf
    
scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${SCRIPTS_DIR}"/nginx \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${tmp_dir}"/nginx/nginx-build.sh 

echo 'Building Nginx image ...'
                                        
ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR} && ${SCRIPTS_DIR}/nginx/nginx-build.sh" \
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

mkdir -p "${tmp_dir}"/sinatra

ssh_run_remote_command "mkdir -p ${SCRIPTS_DIR}/sinatra/dockerctx" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"

ecr_get_repostory_uri "${SINATRA_DOCKER_IMG_NM}" "${registry_uri}"
sinatra_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}/sinatra")/g" \
    -e "s/SEDimage_descSED/sinatra/g" \
    -e "s/SEDregionSED/${region}/g" \
    -e "s/SEDdocker_ctxSED/$(escape "${SCRIPTS_DIR}"/sinatra/dockerctx)/g" \
    -e "s/SEDdocker_repository_uriSED/$(escape "${sinatra_docker_repository_uri}")/g" \
    -e "s/SEDdocker_img_nmSED/$(escape "${SINATRA_DOCKER_IMG_NM}")/g" \
    -e "s/SEDdocker_img_tagSED/${SINATRA_DOCKER_IMG_TAG}/g" \
       "${CONTAINERS_DIR}"/image-build.sh > "${tmp_dir}"/sinatra/sinatra-build.sh  
                                       
echo 'sinatra-build.sh ready.' 

get_application_port 'sinatra'
sinatra_port="${__RESULT}" 

# The Sinatra image is built from the base Ruby image.
sed -e "s/SEDrepository_uriSED/$(escape "${ruby_docker_repository_uri}")/g" \
    -e "s/SEDimg_tagSED/${RUBY_DOCKER_IMG_TAG}/g" \
    -e "s/SEDcontainer_volume_dirSED/$(escape "${SINATRA_DOCKER_CONTAINER_VOLUME_DIR}")/g" \
    -e "s/SEDhttp_portSED/${sinatra_port}/g" \
       "${CONTAINERS_DIR}"/sinatra/Dockerfile > "${tmp_dir}"/sinatra/Dockerfile

echo 'Dockerfile ready.'

scp_upload_file "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${SCRIPTS_DIR}"/sinatra/dockerctx \
    "${tmp_dir}"/sinatra/Dockerfile 

scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${SCRIPTS_DIR}"/sinatra \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${tmp_dir}"/sinatra/sinatra-build.sh  
    
echo 'Building Sinatra image ...'
            
# build Sinatra images in the box and send it to ECR.                             
ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR} && ${SCRIPTS_DIR}/sinatra/sinatra-build.sh" \
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

mkdir -p "${tmp_dir}"/redis

ssh_run_remote_command "mkdir -p ${SCRIPTS_DIR}/redis/dockerctx" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"

ecr_get_repostory_uri "${REDIS_DOCKER_IMG_NM}" "${registry_uri}"
redis_docker_repository_uri="${__RESULT}"
get_application_port 'redis'
redis_port="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}"/redis)/g" \
    -e "s/SEDimage_descSED/redis/g" \
    -e "s/SEDregionSED/${region}/g" \
    -e "s/SEDdocker_ctxSED/$(escape "${SCRIPTS_DIR}"/redis/dockerctx)/g" \
    -e "s/SEDdocker_repository_uriSED/$(escape "${redis_docker_repository_uri}")/g" \
    -e "s/SEDdocker_img_nmSED/$(escape "${REDIS_DOCKER_IMG_NM}")/g" \
    -e "s/SEDdocker_img_tagSED/${REDIS_DOCKER_IMG_TAG}/g" \
    -e "s/SEDip_portSED/${redis_port}/g" \
       "${CONTAINERS_DIR}"/image-build.sh > "${tmp_dir}"/redis-build.sh  
 
echo 'redis-build.sh ready.'  

# The Redis image is built from the Centos image.
ecr_get_repostory_uri "${CENTOS_DOCKER_IMG_NM}" "${registry_uri}"
centos_docker_repository_uri="${__RESULT}"

sed -e "s/SEDrepository_uriSED/$(escape "${centos_docker_repository_uri}")/g" \
    -e "s/SEDimg_tagSED/${CENTOS_DOCKER_IMG_TAG}/g" \
    -e "s/SEDhttp_portSED/${redis_port}/g" \
       "${CONTAINERS_DIR}"/redis/Dockerfile > "${tmp_dir}"/Dockerfile

echo 'Dockerfile ready.'
   
scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${SCRIPTS_DIR}"/redis/dockerctx \
    "${tmp_dir}"/Dockerfile \
    "${CONTAINERS_DIR}"/redis/redis.conf
    
scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${SCRIPTS_DIR}"/redis \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${tmp_dir}"/redis-build.sh

ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR}"/redis \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" 

echo 'Building Redis image ...'
            
# build Redis images in the box and send it to ECR.                             
ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR} && ${SCRIPTS_DIR}/redis/redis-build.sh" \
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

