#!/bin/bash

# shellcheck disable=SC2015

#####################################################
# Creates an EC2 Linux Jenkins box.
# Install a Jenkins server in a Docker container.
#####################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR=/home/"${USER_NM}"/script
JENKINS_DOCKER_CTX="${SCRIPTS_DIR}"/dockerctx

####
STEP 'AWS Jenkins box'
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
jenkins_tmp_dir="${TMP_DIR}"/jenkins
rm -rf  "${jenkins_tmp_dir:?}"
mkdir -p "${jenkins_tmp_dir}"

echo

#
# Security group
#

get_security_group_id "${JENKINS_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -n "${sgp_id}" ]]
then
   echo 'WARN: the Jenkins security group is already created.'
else
   create_security_group "${dtc_id}" "${JENKINS_INST_SEC_GRP_NM}" "${JENKINS_INST_SEC_GRP_NM}" 
   get_security_group_id "${JENKINS_INST_SEC_GRP_NM}"
   sgp_id="${__RESULT}"
   
   echo 'Created Jenkins security group.'
fi

set +e
allow_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e
   
echo 'Granted SSH access to the Jenkins box.'

# 
# Jenkins box
#

check_aws_public_key_exists "${JENKINS_INST_KEY_PAIR_NM}" 
key_exists="${__RESULT}"

if [[ 'false' == "${key_exists}" ]]
then
   # Create a private key in the local 'access' directory.
   mkdir -p "${ACCESS_DIR}"
   generate_aws_keypair "${JENKINS_INST_KEY_PAIR_NM}" "${ACCESS_DIR}" 
   
   echo 'SSH private key created.'
else
   echo 'WARN: SSH key-pair already created.'
fi

get_public_key "${JENKINS_INST_KEY_PAIR_NM}" "${ACCESS_DIR}"
public_key="${__RESULT}"
 
echo 'SSH public key extracted.'

## Removes the default user, creates the user 'awsadmin' and sets the instance's hostname.  

hashed_pwd="$(mkpasswd --method=SHA-512 --rounds=4096 "${USER_PWD}")" 
awk -v key="${public_key}" -v pwd="${hashed_pwd}" -v user="${USER_NM}" -v hostname="${JENKINS_INST_HOSTNAME}" '{
    sub(/SEDuser_nameSED/,user)
    sub(/SEDhashed_passwordSED/,pwd)
    sub(/SEDpublic_keySED/,key)
    sub(/SEDhostnameSED/,hostname)
}1' "${INSTANCE_DIR}"/jenkins/config/cloud_init_template.yml > "${jenkins_tmp_dir}"/cloud_init.yml
 
echo 'cloud_init.yml ready.' 

get_instance_id "${JENKINS_INST_NM}"
instance_id="${__RESULT}"

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${JENKINS_INST_NM}"
   instance_st="${__RESULT}"
   
   if [[ 'running' == "${instance_st}" || \
         'stopped' == "${instance_st}" || \
         'pending' == "${instance_st}" ]]
   then
      echo "WARN: Jenkins box already created (${instance_st})."
   else
      echo "ERROR: Jenkins box already created (${instance_st})."
      
      exit 1
   fi
else
   echo "Creating the Jenkins box ..."

   run_instance \
       "${JENKINS_INST_NM}" \
       "${sgp_id}" \
       "${subnet_id}" \
       "${JENKINS_INST_PRIVATE_IP}" \
       "${shared_image_id}" \
       "${jenkins_tmp_dir}"/cloud_init.yml
       
   get_instance_id "${JENKINS_INST_NM}"
   instance_id="${__RESULT}"    

   echo "Jenkins box created."
fi

# Get the public IP address assigned to the instance. 
get_public_ip_address_associated_with_instance "${JENKINS_INST_NM}"
eip="${__RESULT}"

echo "Jenkins box public address: ${eip}."

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
check_instance_profile_exists "${JENKINS_INST_PROFILE_NM}"
instance_profile_exists="${__RESULT}"

if [[ 'false' == "${instance_profile_exists}" ]]
then
   create_instance_profile "${JENKINS_INST_PROFILE_NM}" 

   echo 'Jenkins instance profile created.'
else
   echo 'WARN: Jenkins instance profile already created.'
fi

get_instance_profile_id "${JENKINS_INST_PROFILE_NM}"
jenkins_instance_profile_id="${__RESULT}"

echo 'Associating instance profile to the instance ...'
check_instance_has_instance_profile_associated "${JENKINS_INST_NM}" "${jenkins_instance_profile_id}"
is_profile_associated="${__RESULT}"

if [[ 'false' == "${is_profile_associated}" ]]
then
   # Associate the instance profile with the Jenkins instance. The instance profile doesn't have a role
   # associated, the role has to added when needed. 
   associate_instance_profile_to_instance "${JENKINS_INST_NM}" "${JENKINS_INST_PROFILE_NM}" > /dev/null 2>&1 && \
   echo 'Jenkins instance profile associated to the instance.' ||
   {
      wait 30
      associate_instance_profile_to_instance "${JENKINS_INST_NM}" "${JENKINS_INST_PROFILE_NM}" > /dev/null 2>&1 && \
      echo 'Jenkins instance profile associated to the instance.' ||
      {
         echo 'ERROR: associating the Jenkins instance profile to the instance.'
         exit 1
      }
   }
else
   echo 'WARN: Jenkins instance profile already associated to the instance.'
fi

echo 'Associating role the instance profile ...'
check_instance_profile_has_role_associated "${JENKINS_INST_PROFILE_NM}" "${JENKINS_ROLE_NM}" 
is_ecr_role_associated="${__RESULT}"

if [[ 'false' == "${is_ecr_role_associated}" ]]
then
   associate_role_to_instance_profile "${JENKINS_INST_PROFILE_NM}" "${JENKINS_ROLE_NM}"
      
   # IAM is a bit slow, progress only when the role is associated to the profile. 
   check_instance_profile_has_role_associated "${JENKINS_INST_PROFILE_NM}" "${JENKINS_ROLE_NM}" && \
   echo 'ECR role associated to the Jenkins instance profile.' ||
   {
      echo 'The role has not been associated to the profile yet.'
      echo 'Let''s wait a bit and check again (second time).' 
      
      wait 180  
      
      echo 'Let''s try now.' 
      
      check_instance_profile_has_role_associated "${JENKINS_INST_PROFILE_NM}" "${JENKINS_ROLE_NM}" && \
      echo 'ECR role associated to the instance profile.' ||
      {
         echo 'ERROR: the role has not been associated to the profile after 3 minutes.'
         exit 1
      }
   } 
else
   echo 'WARN: ECR role already associated to the instance profile.'
fi   

#
echo 'Provisioning the instance ...'
# 

private_key_file="${ACCESS_DIR}"/"${JENKINS_INST_KEY_PAIR_NM}" 
wait_ssh_started "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}"

ssh_run_remote_command "rm -rf ${SCRIPTS_DIR} && mkdir -p ${JENKINS_DOCKER_CTX}" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}"  

# Prepare the scripts to run on the server.

ecr_get_repostory_uri "${JENKINS_DOCKER_IMG_NM}"
jenkins_docker_repository_uri="${__RESULT}"

sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}")/g" \
    -e "s/SEDjenkins_docker_ctxSED/$(escape "${JENKINS_DOCKER_CTX}")/g" \
    -e "s/SEDjenkins_docker_repository_uriSED/$(escape "${jenkins_docker_repository_uri}")/g" \
    -e "s/SEDjenkins_docker_img_nmSED/$(escape "${JENKINS_DOCKER_IMG_NM}")/g" \
    -e "s/SEDjenkins_docker_img_tagSED/${JENKINS_DOCKER_IMG_TAG}/g" \
    -e "s/SEDjenkins_docker_container_nmSED/${JENKINS_DOCKER_CONTAINER_NM}/g" \
    -e "s/SEDjenkins_http_addressSED/${eip}/g" \
    -e "s/SEDjenkins_http_portSED/${JENKINS_HTTP_PORT}/g" \
    -e "s/SEDjenkins_inst_home_dirSED/$(escape "${JENKINS_INST_HOME_DIR}")/g" \
       "${SERVICES_DIR}"/jenkins/jenkins.sh > "${jenkins_tmp_dir}"/jenkins.sh       
  
echo 'Jenkins ready.'  
   
scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${JENKINS_DOCKER_CTX}" \
    "${SERVICES_DIR}"/jenkins/Dockerfile \
    "${SERVICES_DIR}"/jenkins/plugins.txt  
    
scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}" \
    "${LIBRARY_DIR}"/constants/app_consts.sh \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/ecr.sh \
    "${jenkins_tmp_dir}"/jenkins.sh    

ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR}" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" 

ssh_run_remote_command_as_root "${SCRIPTS_DIR}/jenkins.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" && echo 'Jenkins successfully installed.' ||
    {
    
       echo 'The role may not have been associated to the profile yet.'
       echo 'Let''s wait a bit and check again (first time).' 
      
       wait 180  
      
       echo 'Let''s try now.' 
    
       ssh_run_remote_command_as_root "${SCRIPTS_DIR}/jenkins.sh" \
          "${private_key_file}" \
          "${eip}" \
          "${SHARED_INST_SSH_PORT}" \
          "${USER_NM}" \
          "${USER_PWD}" && echo 'Jenkins successfully installed.' ||
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
# Instance profile.
#

check_instance_profile_has_role_associated "${JENKINS_INST_PROFILE_NM}" "${JENKINS_ROLE_NM}"
is_ecr_role_associated="${__RESULT}"

   if [[ 'true' == "${is_ecr_role_associated}" ]]
   then
      ####
      #### Sessions may still be actives, they should be terminated by adding AWSRevokeOlderSessions permission
      #### to the role.
      ####
      remove_role_from_instance_profile "${JENKINS_INST_PROFILE_NM}" "${JENKINS_ROLE_NM}"
     
      echo 'ECR role removed from the instance profile.'
   else
      echo 'WARN: ECR role already removed from the instance profile.'
   fi

   ## 
   ## Instance access.
   ##

   set +e
   revoke_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   
   # Make Jenkins accessible from anywhere in the internet.
   allow_access_from_cidr "${sgp_id}" "${JENKINS_HTTP_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   set -e
   
   echo 'Revoked SSH access to the Jenkins box.'      

echo 'Jenkins box created.'
echo

# Removing old files
# shellcheck disable=SC2115
rm -rf  "${jenkins_tmp_dir:?}"


