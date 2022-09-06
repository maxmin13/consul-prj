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
STEP 'ECR'
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
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* ERROR: Admin box not found.'
   exit 1
fi

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${ADMIN_INST_NM}"
   instance_st="${__RESULT}"
   
   if [[ 'running' == "${instance_st}" ]]
   then
      echo "* Admin box ready (${instance_st})."
   else
      echo "* ERROR: Admin box not ready. (${instance_st})."
      
      exit 1
   fi
fi

get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo '* ERROR: Admin IP address not found.'
   exit 1
else
   echo "* Admin IP address: ${eip}."
fi

get_security_group_id "${ADMIN_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* ERROR: Admin security group not found.'
   exit 1
else
   echo "* Admin security group ID: ${sgp_id}."
fi

# Removing old files
# shellcheck disable=SC2115
ecr_tmp_dir="${TMP_DIR}"/ecr
rm -rf  "${ecr_tmp_dir:?}"
mkdir -p "${ecr_tmp_dir}"

echo

#
# Firewall
#

check_access_is_granted "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/ecr.log 
   
   echo "Access granted on ${SHARED_INST_SSH_PORT} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted on ${SHARED_INST_SSH_PORT} tcp 0.0.0.0/0."
fi

#
# Permissions.
#

check_role_has_permission_policy_attached "${ADMIN_AWS_ROLE_NM}" "${ECR_POLICY_NM}"
is_permission_policy_associated="${__RESULT}"

if [[ 'false' == "${is_permission_policy_associated}" ]]
then
   echo 'Attaching permission policy to the role ...'

   attach_permission_policy_to_role "${ADMIN_AWS_ROLE_NM}" "${ECR_POLICY_NM}"
      
   echo 'Permission policy associated to the role.' 
else
   echo 'WARN: permission policy already associated to the role.'
fi   

private_key_file="${ACCESS_DIR}"/"${ADMIN_INST_KEY_PAIR_NM}" 
wait_ssh_started "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}"
    
# Prepare the scripts to run on the server.

ssh_run_remote_command "rm -rf ${SCRIPTS_DIR:?}" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}"

#
# Centos
#

echo 'Provisioning Centos scripts ...'

mkdir -p "${ecr_tmp_dir}"/centos

ssh_run_remote_command "mkdir -p ${SCRIPTS_DIR}/centos/dockerctx" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}"

ecr_get_repostory_uri "${CENTOS_DOCKER_IMG_NM}"
centos_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}/centos")/g" \
    -e "s/SEDcentos_docker_ctxSED/$(escape "${SCRIPTS_DIR}"/centos/dockerctx)/g" \
    -e "s/SEDcentos_docker_repository_uriSED/$(escape "${centos_docker_repository_uri}")/g" \
    -e "s/SEDcentos_docker_img_nmSED/$(escape "${CENTOS_DOCKER_IMG_NM}")/g" \
    -e "s/SEDcentos_docker_img_tagSED/${CENTOS_DOCKER_IMG_TAG}/g" \
       "${SERVICES_DIR}"/base/centos/centos-install.sh > "${ecr_tmp_dir}"/centos/centos-install.sh  
       
echo 'centos-install.sh ready.' 
    
sed -e "s/SEDbase_centos_docker_repository_uriSED/${BASE_CENTOS_DOCKER_IMG_NM}/g" \
    -e "s/SEDbase_centos_docker_img_tagSED/${BASE_CENTOS_DOCKER_IMG_TAG}/g" \
       "${SERVICES_DIR}"/base/centos/Dockerfile > "${ecr_tmp_dir}"/centos/Dockerfile    
    
echo 'Dockerfile ready.'     

scp_upload_file "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}"/centos/dockerctx \
    "${ecr_tmp_dir}"/centos/Dockerfile   
    
scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}"/centos \
    "${LIBRARY_DIR}"/constants/app_consts.sh \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${ecr_tmp_dir}"/centos/centos-install.sh 
    
echo 'Building Centos image ...'
           
# build Centos images in the box and send it to ECR.                             
ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR} && ${SCRIPTS_DIR}/centos/centos-install.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" >> "${LOGS_DIR}"/ecr.log && echo 'Centos image successfully built.' ||
    {    
       echo 'The role may not have been associated to the profile yet.'
       echo 'Let''s wait a bit and check again (first time).' 
      
       wait 180  
      
       echo 'Let''s try now.' 
    
       ssh_run_remote_command_as_root "${SCRIPTS_DIR}/centos/centos-install.sh" \
          "${private_key_file}" \
          "${eip}" \
          "${SHARED_INST_SSH_PORT}" \
          "${USER_NM}" \
          "${USER_PWD}" >> "${LOGS_DIR}"/ecr.log && echo 'Centos image successfully built.' ||
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

mkdir -p "${ecr_tmp_dir}"/ruby

ssh_run_remote_command "mkdir -p ${SCRIPTS_DIR}/ruby/dockerctx" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}"

ecr_get_repostory_uri "${RUBY_DOCKER_IMG_NM}"
ruby_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}/ruby")/g" \
    -e "s/SEDruby_docker_ctxSED/$(escape "${SCRIPTS_DIR}"/ruby/dockerctx)/g" \
    -e "s/SEDruby_docker_repository_uriSED/$(escape "${ruby_docker_repository_uri}")/g" \
    -e "s/SEDruby_docker_img_nmSED/$(escape "${RUBY_DOCKER_IMG_NM}")/g" \
    -e "s/SEDruby_docker_img_tagSED/${RUBY_DOCKER_IMG_TAG}/g" \
       "${SERVICES_DIR}"/base/ruby/ruby-install.sh > "${ecr_tmp_dir}"/ruby/ruby-install.sh  
       
echo 'ruby-install.sh ready.' 

sed -e "s/SEDruby_docker_repository_uriSED/$(escape "${centos_docker_repository_uri}")/g" \
    -e "s/SEDruby_docker_img_tagSED/${CENTOS_DOCKER_IMG_TAG}/g" \
       "${SERVICES_DIR}"/base/ruby/Dockerfile > "${ecr_tmp_dir}"/ruby/Dockerfile
       
echo 'ruby Dockerfile ready.'        

scp_upload_file "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}"/ruby/dockerctx \
    "${ecr_tmp_dir}"/ruby/Dockerfile
     
scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}"/ruby \
    "${LIBRARY_DIR}"/constants/app_consts.sh \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${ecr_tmp_dir}"/ruby/ruby-install.sh     

echo 'Building Ruby image ...'
            
# build Ruby images in the box and send it to ECR.                             
ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR} && ${SCRIPTS_DIR}/ruby/ruby-install.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" >> "${LOGS_DIR}"/ecr.log && echo 'Ruby image successfully built.' ||
    {
        echo 'ERROR: building Ruby.'
        exit 1   
    }
    
echo   

#
# Jenkins
#

echo 'Provisioning Jenkins scripts ...'

mkdir -p "${ecr_tmp_dir}"/jenkins

ssh_run_remote_command "mkdir -p ${SCRIPTS_DIR}/jenkins/dockerctx" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}"

ecr_get_repostory_uri "${JENKINS_DOCKER_IMG_NM}"
jenkins_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}/jenkins")/g" \
    -e "s/SEDjenkins_docker_ctxSED/$(escape "${SCRIPTS_DIR}"/jenkins/dockerctx)/g" \
    -e "s/SEDjenkins_docker_repository_uriSED/$(escape "${jenkins_docker_repository_uri}")/g" \
    -e "s/SEDjenkins_docker_img_nmSED/$(escape "${JENKINS_DOCKER_IMG_NM}")/g" \
    -e "s/SEDjenkins_docker_img_tagSED/${JENKINS_DOCKER_IMG_TAG}/g" \
       "${SERVICES_DIR}"/jenkins/jenkins-install.sh > "${ecr_tmp_dir}"/jenkins/jenkins-install.sh       
  
echo 'jenkins-install.sh ready.'

sed -e "s/SEDbase_jenkins_docker_repository_uriSED/$(escape ${BASE_JENKINS_DOCKER_IMG_NM})/g" \
    -e "s/SEDbase_jenkins_docker_img_tagSED/${BASE_JENKINS_DOCKER_IMG_TAG}/g" \
       "${SERVICES_DIR}"/jenkins/Dockerfile > "${ecr_tmp_dir}"/jenkins/Dockerfile   
       
echo 'Dockerfile ready.'        
   
scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}"/jenkins/dockerctx \
    "${ecr_tmp_dir}"/jenkins/Dockerfile \
    "${SERVICES_DIR}"/jenkins/plugins.txt  
    
scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}"/jenkins \
    "${LIBRARY_DIR}"/constants/app_consts.sh \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${ecr_tmp_dir}"/jenkins/jenkins-install.sh         

echo 'Building Jenkins image ...'

ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR} && ${SCRIPTS_DIR}/jenkins/jenkins-install.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" >> "${LOGS_DIR}"/ecr.log && echo 'Jenkins image successfully built.' ||
    {
        echo 'ERROR: building Jenkins.'
        exit 1   
    } 
    
echo

#
# Nginx
#

echo 'Provisioning Nginx scripts ...'

mkdir -p "${ecr_tmp_dir}"/nginx

ssh_run_remote_command "mkdir -p ${SCRIPTS_DIR}/nginx/dockerctx" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}"

ecr_get_repostory_uri "${NGINX_DOCKER_IMG_NM}"
nginx_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}/nginx")/g" \
    -e "s/SEDnginx_docker_ctxSED/$(escape "${SCRIPTS_DIR}"/nginx/dockerctx)/g" \
    -e "s/SEDnginx_docker_repository_uriSED/$(escape "${nginx_docker_repository_uri}")/g" \
    -e "s/SEDnginx_docker_img_nmSED/$(escape "${NGINX_DOCKER_IMG_NM}")/g" \
    -e "s/SEDnginx_docker_img_tagSED/${NGINX_DOCKER_IMG_TAG}/g" \
    -e "s/SEDnginx_http_portSED/${NGINX_HTTP_PORT}/g" \
       "${SERVICES_DIR}"/nginx/nginx-install.sh > "${ecr_tmp_dir}"/nginx/nginx-install.sh  
                        
echo 'nginx-install.sh ready.'  

# The Nginx image is built from the base Centos image.
sed -e "s/SEDrepository_uriSED/$(escape "${centos_docker_repository_uri}")/g" \
    -e "s/SEDimg_tagSED/${CENTOS_DOCKER_IMG_TAG}/g" \
    -e "s/SEDnginx_container_volume_dirSED/$(escape "${NGINX_CONTAINER_VOLUME_DIR}")/g" \
       "${SERVICES_DIR}"/nginx/Dockerfile > "${ecr_tmp_dir}"/nginx/Dockerfile

echo 'Dockerfile ready.'

sed -e "s/SEDnginx_container_volume_dirSED/$(escape "${NGINX_CONTAINER_VOLUME_DIR}")/g" \
       "${SERVICES_DIR}"/nginx/global.conf > "${ecr_tmp_dir}"/nginx/global.conf
    
echo 'global.conf ready.'  

scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}"/nginx/dockerctx \
    "${ecr_tmp_dir}"/nginx/Dockerfile \
    "${ecr_tmp_dir}"/nginx/global.conf \
    "${SERVICES_DIR}"/nginx/nginx.conf
    
scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}"/nginx \
    "${LIBRARY_DIR}"/constants/app_consts.sh \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${ecr_tmp_dir}"/nginx/nginx-install.sh 

echo 'Building Nginx image ...'
                                        
ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR} && ${SCRIPTS_DIR}/nginx/nginx-install.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" >> "${LOGS_DIR}"/ecr.log && echo 'Nginx image successfully built.' ||
    {
        echo 'ERROR: building Nginx.'
        exit 1   
    }   
    
echo 

#
# Sinatra
#

echo 'Provisioning Sinatra scripts ...'

mkdir -p "${ecr_tmp_dir}"/sinatra

ssh_run_remote_command "mkdir -p ${SCRIPTS_DIR}/sinatra/dockerctx" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}"

ecr_get_repostory_uri "${SINATRA_DOCKER_IMG_NM}"
sinatra_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}/sinatra")/g" \
    -e "s/SEDsinatra_docker_ctxSED/$(escape "${SCRIPTS_DIR}"/sinatra/dockerctx)/g" \
    -e "s/SEDsinatra_docker_repository_uriSED/$(escape "${sinatra_docker_repository_uri}")/g" \
    -e "s/SEDsinatra_docker_img_nmSED/$(escape "${SINATRA_DOCKER_IMG_NM}")/g" \
    -e "s/SEDsinatra_docker_img_tagSED/${SINATRA_DOCKER_IMG_TAG}/g" \
    -e "s/SEDsinatra_docker_container_nmSED/${SINATRA_DOCKER_CONTAINER_NM}/g" \
    -e "s/SEDsinatra_http_portSED/${SINATRA_HTTP_PORT}/g" \
       "${SERVICES_DIR}"/sinatra/sinatra-install.sh > "${ecr_tmp_dir}"/sinatra/sinatra-install.sh  
                        
echo 'sinatra.sh ready.'  

# The Sinatra image is built from the base Ruby image.
sed -e "s/SEDrepository_uriSED/$(escape "${ruby_docker_repository_uri}")/g" \
    -e "s/SEDimg_tagSED/${RUBY_DOCKER_IMG_TAG}/g" \
    -e "s/SEDcontainer_volume_dirSED/$(escape "${SINATRA_DOCKER_CONTAINER_VOLUME_DIR}")/g" \
       "${SERVICES_DIR}"/sinatra/Dockerfile > "${ecr_tmp_dir}"/sinatra/Dockerfile

echo 'Dockerfile ready.'

scp_upload_file "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}"/sinatra/dockerctx \
    "${ecr_tmp_dir}"/sinatra/Dockerfile 

scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}"/sinatra \
    "${LIBRARY_DIR}"/constants/app_consts.sh \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${ecr_tmp_dir}"/sinatra/sinatra-install.sh  
    
echo 'Building Sinatra image ...'
            
# build Sinatra images in the box and send it to ECR.                             
ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR} && ${SCRIPTS_DIR}/sinatra/sinatra-install.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" >> "${LOGS_DIR}"/ecr.log && echo 'Sinatra image successfully built.' ||
    {
        echo 'ERROR: building Sinatra.'
        exit 1   
    }    
   
#
# Redis
#   

echo 'Provisioning Redis scripts ...'

mkdir -p "${ecr_tmp_dir}"/redis

ssh_run_remote_command "mkdir -p ${SCRIPTS_DIR}/redis/dockerctx" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}"

ecr_get_repostory_uri "${REDIS_DOCKER_IMG_NM}"
redis_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}"/redis)/g" \
    -e "s/SEDredis_docker_ctxSED/$(escape "${SCRIPTS_DIR}"/redis/dockerctx)/g" \
    -e "s/SEDredis_docker_repository_uriSED/$(escape "${redis_docker_repository_uri}")/g" \
    -e "s/SEDredis_docker_img_nmSED/$(escape "${REDIS_DOCKER_IMG_NM}")/g" \
    -e "s/SEDredis_docker_img_tagSED/${REDIS_DOCKER_IMG_TAG}/g" \
    -e "s/SEDredis_ip_portSED/${REDIS_IP_PORT}/g" \
       "${SERVICES_DIR}"/redis/redis-install.sh > "${ecr_tmp_dir}"/redis-install.sh  
  
echo 'redis-install.sh ready.'  

# The Redis image is built from a base Centos image.
ecr_get_repostory_uri "${CENTOS_DOCKER_IMG_NM}"
centos_docker_repository_uri="${__RESULT}"

sed -e "s/SEDrepository_uriSED/$(escape "${centos_docker_repository_uri}")/g" \
    -e "s/SEDimg_tagSED/${CENTOS_DOCKER_IMG_TAG}/g" \
       "${SERVICES_DIR}"/redis/Dockerfile > "${ecr_tmp_dir}"/Dockerfile

echo 'Dockerfile ready.'
   
scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}"/redis/dockerctx \
    "${ecr_tmp_dir}"/Dockerfile \
    "${SERVICES_DIR}"/redis/redis.conf
    
scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}"/redis \
    "${LIBRARY_DIR}"/constants/app_consts.sh \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${ecr_tmp_dir}"/redis-install.sh

ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR}"/redis \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" 

echo 'Building Redis image ...'
            
# build Redis images in the box and send it to ECR.                             
ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR} && ${SCRIPTS_DIR}/redis/redis-install.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" >> "${LOGS_DIR}"/ecr.log && echo 'Redis image successfully built.' ||
    {
        echo 'ERROR: building Redis.'
        exit 1   
    }    
   
echo
                           
ssh_run_remote_command "rm -rf ${SCRIPTS_DIR:?}" \
    "${private_key_file}" \
    "${eip}" \
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
## Firewall.
##

check_access_is_granted "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'true' == "${is_granted}" ]]
then
   revoke_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/ecr.log  
   
   echo "Access revoked on ${SHARED_INST_SSH_PORT} tcp 0.0.0.0/0."
else
   echo "WARN: access already revoked ${SHARED_INST_SSH_PORT} tcp 0.0.0.0/0."
fi

echo 'Revoked SSH access to the box.'      

echo

# Removing old files
# shellcheck disable=SC2115
rm -rf  "${ecr_tmp_dir:?}"

