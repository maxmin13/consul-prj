#!/bin/bash

# shellcheck disable=SC2015

#####################################################
# Creates an EC2 Linux Sinatra box.
# Install a Sinatra server in a Docker container and
# runs it in the default Docker bridge network.
#####################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR=/home/"${USER_NM}"/script
SINATRA_DOCKER_CTX="${SCRIPTS_DIR}"/dockerctx
SINATRA_ARCHIVE='webapp.zip'
SINATRA_DOCKER_CONTAINER_NETWORK_NM='bridge'

####
STEP 'AWS Sinatra box'
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
sinatra_tmp_dir="${TMP_DIR}"/sinatra
rm -rf  "${sinatra_tmp_dir:?}"
mkdir -p "${sinatra_tmp_dir}"

echo

#
# Security group
#

get_security_group_id "${SINATRA_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -n "${sgp_id}" ]]
then
   echo 'WARN: the Sinatra security group is already created.'
else
   create_security_group "${dtc_id}" "${SINATRA_INST_SEC_GRP_NM}" "${SINATRA_INST_SEC_GRP_NM}" 
   get_security_group_id "${SINATRA_INST_SEC_GRP_NM}"
   sgp_id="${__RESULT}"
   
   echo 'Created Sinatra security group.'
fi

set +e
allow_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e
   
echo 'Granted SSH access to the Sinatra box.'

# 
# Sinatra box
#

check_aws_public_key_exists "${SINATRA_INST_KEY_PAIR_NM}" 
key_exists="${__RESULT}"

if [[ 'false' == "${key_exists}" ]]
then
   # Create a private key in the local 'access' directory.
   mkdir -p "${ACCESS_DIR}"
   generate_aws_keypair "${SINATRA_INST_KEY_PAIR_NM}" "${ACCESS_DIR}" 
   
   echo 'SSH private key created.'
else
   echo 'WARN: SSH key-pair already created.'
fi

get_public_key "${SINATRA_INST_KEY_PAIR_NM}" "${ACCESS_DIR}"
public_key="${__RESULT}"
 
echo 'SSH public key extracted.'

## Removes the default user, creates the user 'awsadmin' and sets the instance's hostname.     

hashed_pwd="$(mkpasswd --method=SHA-512 --rounds=4096 "${USER_PWD}")" 
awk -v key="${public_key}" -v pwd="${hashed_pwd}" -v user="${USER_NM}" -v hostname="${SINATRA_INST_HOSTNAME}" '{
    sub(/SEDuser_nameSED/,user)
    sub(/SEDhashed_passwordSED/,pwd)
    sub(/SEDpublic_keySED/,key)
    sub(/SEDhostnameSED/,hostname)
}1' "${INSTANCE_DIR}"/sinatra/config/cloud_init_template.yml > "${sinatra_tmp_dir}"/cloud_init.yml
 
echo 'cloud_init.yml ready.' 

get_instance_id "${SINATRA_INST_NM}"
instance_id="${__RESULT}"

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${SINATRA_INST_NM}"
   instance_st="${__RESULT}"
   
   if [[ 'running' == "${instance_st}" || \
         'stopped' == "${instance_st}" || \
         'pending' == "${instance_st}" ]]
   then
      echo "WARN: Sinatra box already created (${instance_st})."
   else
      echo "ERROR: Sinatra box already created (${instance_st})."
      
      exit 1
   fi
else
   echo "Creating the Sinatra box ..."

   run_instance \
       "${SINATRA_INST_NM}" \
       "${sgp_id}" \
       "${subnet_id}" \
       "${SINATRA_INST_PRIVATE_IP}" \
       "${shared_image_id}" \
       "${sinatra_tmp_dir}"/cloud_init.yml
       
   get_instance_id "${SINATRA_INST_NM}"
   instance_id="${__RESULT}"    

   echo "Sinatra box created."
fi

# Get the public IP address assigned to the instance. 
get_public_ip_address_associated_with_instance "${SINATRA_INST_NM}"
eip="${__RESULT}"

echo "Sinatra box public address: ${eip}."

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
check_instance_profile_exists "${SINATRA_INST_PROFILE_NM}"
instance_profile_exists="${__RESULT}"

if [[ 'false' == "${instance_profile_exists}" ]]
then
   create_instance_profile "${SINATRA_INST_PROFILE_NM}" 

   echo 'Sinatra instance profile created.'
else
   echo 'WARN: Sinatra instance profile already created.'
fi

get_instance_profile_id "${SINATRA_INST_PROFILE_NM}"
sinatra_instance_profile_id="${__RESULT}"

echo 'Associating instance profile to the instance ...'
check_instance_has_instance_profile_associated "${SINATRA_INST_NM}" "${sinatra_instance_profile_id}"
is_profile_associated="${__RESULT}"

if [[ 'false' == "${is_profile_associated}" ]]
then
   # Associate the instance profile with the Sinatra instance. The instance profile doesn't have a role
   # associated, the role has to added when needed. 
   associate_instance_profile_to_instance "${SINATRA_INST_NM}" "${SINATRA_INST_PROFILE_NM}" > /dev/null 2>&1 && \
   echo 'Sinatra instance profile associated to the instance.' ||
   {
      wait 30
      associate_instance_profile_to_instance "${SINATRA_INST_NM}" "${SINATRA_INST_PROFILE_NM}" > /dev/null 2>&1 && \
      echo 'Sinatra instance profile associated to the instance.' ||
      {
         echo 'ERROR: associating the Sinatra instance profile to the instance.'
         exit 1
      }
   }
else
   echo 'WARN: Sinatra instance profile already associated to the instance.'
fi

echo 'Associating role the instance profile ...'
check_instance_profile_has_role_associated "${SINATRA_INST_PROFILE_NM}" "${SINATRA_ROLE_NM}" 
is_ecr_role_associated="${__RESULT}"

if [[ 'false' == "${is_ecr_role_associated}" ]]
then
   associate_role_to_instance_profile "${SINATRA_INST_PROFILE_NM}" "${SINATRA_ROLE_NM}"
      
   # IAM is a bit slow, progress only when the role is associated to the profile. 
   check_instance_profile_has_role_associated "${SINATRA_INST_PROFILE_NM}" "${SINATRA_ROLE_NM}" && \
   echo 'ECR role associated to the Sinatra instance profile.' ||
   {
      echo 'The role has not been associated to the profile yet.'
      echo 'Let''s wait a bit and check again (second time).' 
      
      wait 180  
      
      echo 'Let''s try now.' 
      
      check_instance_profile_has_role_associated "${SINATRA_INST_PROFILE_NM}" "${SINATRA_ROLE_NM}" && \
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

private_key_file="${ACCESS_DIR}"/"${SINATRA_INST_KEY_PAIR_NM}" 
wait_ssh_started "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}"

ssh_run_remote_command "rm -rf ${SCRIPTS_DIR} && mkdir -p ${SINATRA_DOCKER_CTX}" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}"  

# Prepare the scripts to run on the server.

ecr_get_repostory_uri "${SINATRA_DOCKER_IMG_NM}"
sinatra_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}")/g" \
    -e "s/SEDsinatra_docker_ctxSED/$(escape "${SINATRA_DOCKER_CTX}")/g" \
    -e "s/SEDsinatra_docker_repository_uriSED/$(escape "${sinatra_docker_repository_uri}")/g" \
    -e "s/SEDsinatra_docker_img_nmSED/$(escape "${SINATRA_DOCKER_IMG_NM}")/g" \
    -e "s/SEDsinatra_docker_img_tagSED/${SINATRA_DOCKER_IMG_TAG}/g" \
    -e "s/SEDsinatra_docker_container_nmSED/${SINATRA_DOCKER_CONTAINER_NM}/g" \
    -e "s/SEDsinatra_docker_container_volume_dirSED/$(escape "${SINATRA_DOCKER_CONTAINER_VOLUME_DIR}")/g" \
    -e "s/SEDsinatra_docker_host_volume_dirSED/$(escape "${SINATRA_DOCKER_HOST_VOLUME_DIR}")/g" \
    -e "s/SEDsinatra_docker_container_network_nmSED/${SINATRA_DOCKER_CONTAINER_NETWORK_NM}/g" \
    -e "s/SEDsinatra_http_addressSED/${eip}/g" \
    -e "s/SEDsinatra_http_portSED/${SINATRA_HTTP_PORT}/g" \
    -e "s/SEDsinatra_archiveSED/${SINATRA_ARCHIVE}/g" \
       "${SERVICES_DIR}"/sinatra/sinatra.sh > "${sinatra_tmp_dir}"/sinatra.sh  
                        
echo 'sinatra.sh ready.'  

# The Sinatra image is built from a base Ruby image.
ecr_get_repostory_uri "${RUBY_DOCKER_IMG_NM}"
ruby_docker_repository_uri="${__RESULT}"

sed -e "s/SEDrepository_uriSED/$(escape "${ruby_docker_repository_uri}")/g" \
    -e "s/SEDimg_tagSED/${RUBY_DOCKER_IMG_TAG}/g" \
    -e "s/SEDcontainer_volume_dirSED/$(escape "${SINATRA_DOCKER_CONTAINER_VOLUME_DIR}")/g" \
       "${SERVICES_DIR}"/sinatra/Dockerfile > "${sinatra_tmp_dir}"/Dockerfile

echo 'Dockerfile ready.' 

## Sinatra webapp
cd "${sinatra_tmp_dir}" || exit
cp -R "${SERVICES_DIR}"/sinatra/webapp .
zip -r "${SINATRA_ARCHIVE}" webapp > /dev/null 2>&1

echo "${SINATRA_ARCHIVE} ready." 
   
scp_upload_file "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SINATRA_DOCKER_CTX}" \
    "${sinatra_tmp_dir}"/Dockerfile 
    
scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}" \
    "${LIBRARY_DIR}"/constants/app_consts.sh \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${sinatra_tmp_dir}"/sinatra.sh \
    "${sinatra_tmp_dir}"/"${SINATRA_ARCHIVE}" 

ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR}" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" 
    
ssh_run_remote_command_as_root "${SCRIPTS_DIR}/sinatra.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" && echo 'Sinatra successfully installed.' ||
    {
    
       echo 'The role may not have been associated to the profile yet.'
       echo 'Let''s wait a bit and check again (first time).' 
      
       wait 180  
      
       echo 'Let''s try now.' 
    
       ssh_run_remote_command_as_root "${SCRIPTS_DIR}/sinatra.sh" \
          "${private_key_file}" \
          "${eip}" \
          "${SHARED_INST_SSH_PORT}" \
          "${USER_NM}" \
          "${USER_PWD}" && echo 'Sinatra successfully installed.' ||
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

check_instance_profile_has_role_associated "${SINATRA_INST_PROFILE_NM}" "${SINATRA_ROLE_NM}"
is_ecr_role_associated="${__RESULT}"

   if [[ 'true' == "${is_ecr_role_associated}" ]]
   then
      ####
      #### Sessions may still be actives, they should be terminated by adding AWSRevokeOlderSessions permission
      #### to the role.
      ####
      remove_role_from_instance_profile "${SINATRA_INST_PROFILE_NM}" "${SINATRA_ROLE_NM}"
     
      echo 'ECR role removed from the instance profile.'
   else
      echo 'WARN: ECR role already removed from the instance profile.'
   fi

   ## 
   ## Instance access.
   ##

   set +e
   revoke_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   
   # Make Sinatra accessible from anywhere in the internet.
   allow_access_from_cidr "${sgp_id}" "${SINATRA_HTTP_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   set -e
   
   echo 'Revoked SSH access to the Sinatra box.'      

echo 'Sinatra box created.'
echo

# Removing old files
# shellcheck disable=SC2115
rm -rf  "${sinatra_tmp_dir:?}"


