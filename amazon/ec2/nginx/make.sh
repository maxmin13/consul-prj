#!/bin/bash

# shellcheck disable=SC2015

#####################################################
# Creates an EC2 Linux Nginx box.
# Install a Nginx server in a Docker container.
#####################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR=/home/"${USER_NM}"/script
NGINX_DOCKER_CTX="${SCRIPTS_DIR}"/dockerctx
WEBSITE_ARCHIVE='welcome.zip'
WEBSITE_NM='welcome'

####
STEP 'AWS Nginx box'
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

get_image_id "${SHARED_IMG_NM}"
shared_image_id="${__RESULT}"

if [[ -z "${shared_image_id}" ]]
then
   echo '* ERROR: Shared image not found.'
   exit 1
else
   echo "* Shared image ID: ${shared_image_id}."
fi

# Removing old files
# shellcheck disable=SC2115
nginx_tmp_dir="${TMP_DIR}"/nginx
rm -rf  "${nginx_tmp_dir:?}"
mkdir -p "${nginx_tmp_dir}"

echo

#
# Security group
#

get_security_group_id "${NGINX_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -n "${sgp_id}" ]]
then
   echo 'WARN: the Nginx security group is already created.'
else
   create_security_group "${dtc_id}" "${NGINX_INST_SEC_GRP_NM}" "${NGINX_INST_SEC_GRP_NM}" 
   get_security_group_id "${NGINX_INST_SEC_GRP_NM}"
   sgp_id="${__RESULT}"
   
   echo 'Created Nginx security group.'
fi

set +e
allow_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e
   
echo 'Granted SSH access to the Nginx box.'

# 
# Nginx box
#

check_aws_public_key_exists "${NGINX_INST_KEY_PAIR_NM}" 
key_exists="${__RESULT}"

if [[ 'false' == "${key_exists}" ]]
then
   # Create a private key in the local 'access' directory.
   mkdir -p "${ACCESS_DIR}"
   generate_aws_keypair "${NGINX_INST_KEY_PAIR_NM}" "${ACCESS_DIR}" 
   
   echo 'SSH private key created.'
else
   echo 'WARN: SSH key-pair already created.'
fi

get_public_key "${NGINX_INST_KEY_PAIR_NM}" "${ACCESS_DIR}"
public_key="${__RESULT}"
 
echo 'SSH public key extracted.'

## Removes the default user, creates the user 'awsadmin' and sets the instance's hostname.     

hashed_pwd="$(mkpasswd --method=SHA-512 --rounds=4096 "${USER_PWD}")" 
awk -v key="${public_key}" -v pwd="${hashed_pwd}" -v user="${USER_NM}" -v hostname="${NGINX_INST_HOSTNAME}" '{
    sub(/SEDuser_nameSED/,user)
    sub(/SEDhashed_passwordSED/,pwd)
    sub(/SEDpublic_keySED/,key)
    sub(/SEDhostnameSED/,hostname)
}1' "${INSTANCE_DIR}"/nginx/config/cloud_init_template.yml > "${nginx_tmp_dir}"/cloud_init.yml
 
echo 'cloud_init.yml ready.' 

get_instance_id "${NGINX_INST_NM}"
instance_id="${__RESULT}"

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${NGINX_INST_NM}"
   instance_st="${__RESULT}"
   
   if [[ 'running' == "${instance_st}" || \
         'stopped' == "${instance_st}" || \
         'pending' == "${instance_st}" ]]
   then
      echo "WARN: Nginx box already created (${instance_st})."
   else
      echo "ERROR: Nginx box already created (${instance_st})."
      
      exit 1
   fi
else
   echo "Creating the Nginx box ..."

   run_instance \
       "${NGINX_INST_NM}" \
       "${sgp_id}" \
       "${subnet_id}" \
       "${NGINX_INST_PRIVATE_IP}" \
       "${shared_image_id}" \
       "${nginx_tmp_dir}"/cloud_init.yml
       
   get_instance_id "${NGINX_INST_NM}"
   instance_id="${__RESULT}"    

   echo "Nginx box created."
fi

# Get the public IP address assigned to the instance. 
get_public_ip_address_associated_with_instance "${NGINX_INST_NM}"
eip="${__RESULT}"

echo "Nginx box public address: ${eip}."

#
# Instance profile.
#

# Applications that run on EC2 instances must sign their API requests with AWS credentials.
# For applications, AWS CLI, and Tools for Windows PowerShell commands that run on the instance, 
# you do not have to explicitly get the temporary security credentials, the AWS SDKs, AWS CLI, and 
# Tools for Windows PowerShell automatically get the credentials from the EC2 instance metadata 
# service and use them. 
# see: aws sts get-caller-identity

echo 'Creating instance profile ...'
check_instance_profile_exists "${NGINX_INST_PROFILE_NM}"
instance_profile_exists="${__RESULT}"

if [[ 'false' == "${instance_profile_exists}" ]]
then
   create_instance_profile "${NGINX_INST_PROFILE_NM}" 

   echo 'Nginx instance profile created.'
else
   echo 'WARN: Nginx instance profile already created.'
fi

get_instance_profile_id "${NGINX_INST_PROFILE_NM}"
nginx_instance_profile_id="${__RESULT}"

echo 'Associating instance profile to the instance ...'
check_instance_has_instance_profile_associated "${NGINX_INST_NM}" "${nginx_instance_profile_id}"
is_profile_associated="${__RESULT}"

if [[ 'false' == "${is_profile_associated}" ]]
then
   # Associate the instance profile with the Nginx instance. The instance profile doesn't have a role
   # associated, the role has to added when needed. 
   associate_instance_profile_to_instance "${NGINX_INST_NM}" "${NGINX_INST_PROFILE_NM}" > /dev/null 2>&1 && \
   echo 'Nginx instance profile associated to the instance.' ||
   {
      wait 30
      associate_instance_profile_to_instance "${NGINX_INST_NM}" "${NGINX_INST_PROFILE_NM}" > /dev/null 2>&1 && \
      echo 'Nginx instance profile associated to the instance.' ||
      {
         echo 'ERROR: associating the Nginx instance profile to the instance.'
         exit 1
      }
   }
else
   echo 'WARN: Nginx instance profile already associated to the instance.'
fi

echo 'Associating role the instance profile ...'
check_instance_profile_has_role_associated "${NGINX_INST_PROFILE_NM}" "${NGINX_ROLE_NM}" 
is_ecr_role_associated="${__RESULT}"

if [[ 'false' == "${is_ecr_role_associated}" ]]
then
   associate_role_to_instance_profile "${NGINX_INST_PROFILE_NM}" "${NGINX_ROLE_NM}"
      
   # IAM is a bit slow, progress only when the role is associated to the profile. 
   check_instance_profile_has_role_associated "${NGINX_INST_PROFILE_NM}" "${NGINX_ROLE_NM}" && \
   echo 'ECR role associated to the Nginx instance profile.' ||
   {
      echo 'The role has not been associated to the profile yet.'
      echo 'Let''s wait a bit and check again (second time).' 
      
      wait 180  
      
      echo 'Let''s try now.' 
      
      check_instance_profile_has_role_associated "${NGINX_INST_PROFILE_NM}" "${NGINX_ROLE_NM}" && \
      echo 'ECR role associated to the instance profile.' ||
      {
         echo 'ERROR: the role has not been associated to the profile after 3 minuts.'
         exit 1
      }
   } 
else
   echo 'WARN: ECR role already associated to the instance profile.'
fi    

#
echo 'Provisioning the instance ...'
# 

private_key_file="${ACCESS_DIR}"/"${NGINX_INST_KEY_PAIR_NM}" 
wait_ssh_started "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}"

ssh_run_remote_command "rm -rf ${SCRIPTS_DIR} && mkdir -p ${NGINX_DOCKER_CTX}" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}"  

# Prepare the scripts to run on the server.

ecr_get_repostory_uri "${NGINX_DOCKER_IMG_NM}"
nginx_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}")/g" \
    -e "s/SEDnginx_docker_ctxSED/$(escape "${NGINX_DOCKER_CTX}")/g" \
    -e "s/SEDnginx_docker_repository_uriSED/$(escape "${nginx_docker_repository_uri}")/g" \
    -e "s/SEDnginx_docker_img_nmSED/$(escape "${NGINX_DOCKER_IMG_NM}")/g" \
    -e "s/SEDnginx_docker_img_tagSED/${NGINX_DOCKER_IMG_TAG}/g" \
    -e "s/SEDnginx_docker_container_nmSED/${NGINX_DOCKER_CONTAINER_NM}/g" \
    -e "s/SEDnginx_http_addressSED/${eip}/g" \
    -e "s/SEDnginx_http_portSED/${NGINX_HTTP_PORT}/g" \
    -e "s/SEDnginx_inst_webapps_dirSED/$(escape "${NGINX_INST_WEBAPPS_DIR}")/g" \
    -e "s/SEDnginx_container_volume_dirSED/$(escape "${NGINX_CONTAINER_VOLUME_DIR}")/g" \
    -e "s/SEDwebsite_archiveSED/${WEBSITE_ARCHIVE}/g" \
    -e "s/SEDwebsite_nmSED/${WEBSITE_NM}/g" \
       "${SERVICES_DIR}"/nginx/nginx.sh > "${nginx_tmp_dir}"/nginx.sh  
                        
echo 'nginx.sh ready.'  

# The Nginx image is built from a base Centos image.
ecr_get_repostory_uri "${CENTOS_DOCKER_IMG_NM}"
centos_docker_repository_uri="${__RESULT}"

sed -e "s/SEDrepository_uriSED/$(escape "${centos_docker_repository_uri}")/g" \
    -e "s/SEDimg_tagSED/${CENTOS_DOCKER_IMG_TAG}/g" \
    -e "s/SEDnginx_container_volume_dirSED/$(escape "${NGINX_CONTAINER_VOLUME_DIR}")/g" \
       "${SERVICES_DIR}"/nginx/Dockerfile > "${nginx_tmp_dir}"/Dockerfile

echo 'Dockerfile ready.'

sed -e "s/SEDnginx_container_volume_dirSED/$(escape "${NGINX_CONTAINER_VOLUME_DIR}")/g" \
       "${SERVICES_DIR}"/nginx/global.conf > "${nginx_tmp_dir}"/global.conf
    
echo 'global.conf ready.'  

## Website sources
cd "${nginx_tmp_dir}" || exit
cp -R "${SERVICES_DIR}"/nginx/website './'
cd "${nginx_tmp_dir}"/website || exit
zip -r ../"${WEBSITE_ARCHIVE}" ./* > /dev/null 2>&1

echo "${WEBSITE_ARCHIVE} ready"
   
scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${NGINX_DOCKER_CTX}" \
    "${nginx_tmp_dir}"/global.conf \
    "${SERVICES_DIR}"/nginx/nginx.conf \
    "${nginx_tmp_dir}"/Dockerfile 
    
scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}" \
    "${LIBRARY_DIR}"/constants/app_consts.sh \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${nginx_tmp_dir}"/nginx.sh \
    "${nginx_tmp_dir}"/"${WEBSITE_ARCHIVE}" 

ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR}" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" 
    
ssh_run_remote_command_as_root "${SCRIPTS_DIR}/nginx.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" && echo 'Nginx successfully installed.' ||
    {
    
       echo 'The role may not have been associated to the profile yet.'
       echo 'Let''s wait a bit and check again (first time).' 
      
       wait 180  
      
       echo 'Let''s try now.' 
    
       ssh_run_remote_command_as_root "${SCRIPTS_DIR}/nginx.sh" \
          "${private_key_file}" \
          "${eip}" \
          "${SHARED_INST_SSH_PORT}" \
          "${USER_NM}" \
          "${USER_PWD}" && echo 'Nginx successfully installed.' ||
          {
              echo 'ERROR: the problem persists after 3 minutes.'
              exit 1          
          }
    }

ssh_run_remote_command "rm -rf ${SCRIPTS_DIR}" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" 
    
#
# Instance profile
#

check_instance_profile_has_role_associated "${NGINX_INST_PROFILE_NM}" "${NGINX_ROLE_NM}"
is_ecr_role_associated="${__RESULT}"

   if [[ 'true' == "${is_ecr_role_associated}" ]]
   then
      ####
      #### Sessions may still be actives, they should be terminated by adding AWSRevokeOlderSessions permission
      #### to the role.
      ####
      remove_role_from_instance_profile "${NGINX_INST_PROFILE_NM}" "${NGINX_ROLE_NM}"
     
      echo 'ECR role removed from the instance profile.'
   else
      echo 'WARN: ECR role already removed from the instance profile.'
   fi

   ## 
   ## Instance access.
   ##

   set +e
  revoke_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   
   # Make Nginx accessible from anywhere in the internet.
   allow_access_from_cidr "${sgp_id}" "${NGINX_HTTP_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   set -e
   
   echo 'Revoked SSH access to the Nginx box.'      

echo 'Nginx box created.'
echo

# Removing old files
# shellcheck disable=SC2115
rm -rf  "${nginx_tmp_dir:?}"


