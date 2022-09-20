#!/bin/bash

# shellcheck disable=SC2015

#####################################################
# Configures the instance profile of a box.
#####################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# Enforce parameter
if [ "$#" -lt 1 ]; then
  echo "USAGE: instance_key"
  echo "EXAMPLE: admin"
  echo "Only provided $# arguments"
  exit 1
fi

instance_key="${1}"
logfile_nm="${instance_key}".log

####
STEP "${instance_key} box permissions"
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

get_instance_profile_name "${instance_key}"
instance_profile_nm="${__RESULT}"
check_instance_profile_exists "${instance_profile_nm}"
instance_profile_exists="${__RESULT}"
get_instance_profile_id "${instance_profile_nm}" 
instance_profile_id="${__RESULT}"

if [[ 'true' == "${instance_profile_exists}" ]]
then
   echo "* ${instance_key} instance profile ID: ${instance_profile_id}"
else
   echo "* WARN: ${instance_key} instance profile not found."
fi

get_role_name "${instance_key}"
role_nm="${__RESULT}"
check_role_exists "${role_nm}"
role_exists="${__RESULT}"

if [[ 'true' == "${role_exists}" ]]
then
   get_role_arn "${role_nm}" >> "${LOGS_DIR}"/"${logfile_nm}"
   role_arn="${__RESULT}"

   echo "* ${instance_key} role ARN: ${role_arn}"
else
   echo "* WARN: ${instance_key} role not found."
fi

echo

#
# Permissions.
#

# Applications that run on EC2 instances must sign their API requests with AWS credentials.
# For applications, AWS CLI, and Tools for Windows PowerShell commands that run on the instance, 
# you do not have to explicitly get the temporary security credentials, the AWS SDKs, AWS CLI, and 
# Tools for Windows PowerShell automatically get the credentials from the EC2 instance metadata 
# service and use them. 
# see: aws sts get-caller-identity

if [[ 'false' == "${instance_profile_exists}" ]]
then
   echo "Creating ${instance_key} instance profile ..."

   create_instance_profile "${instance_profile_nm}" >> "${LOGS_DIR}"/"${logfile_nm}"

   echo "${instance_key} instance profile created."
else
   echo "WARN: ${instance_key} instance profile already created."
fi

check_instance_has_instance_profile_associated "${instance_nm}" "${instance_profile_id}"
is_profile_associated="${__RESULT}"

if [[ 'false' == "${is_profile_associated}" ]]
then
   echo "Associating instance profile to ${instance_key} instance ..."

   associate_instance_profile_to_instance_and_wait "${instance_nm}" "${instance_profile_nm}" >> "${LOGS_DIR}"/"${logfile_nm}" 2>&1 
   
   echo "Instance profile associated to ${instance_key} instance."
else
   echo "WARN: instance profile already associated to ${instance_key} instance."
fi

# Create the trust relationship policy document that grants the EC2 instances the
# permission to assume the role.
build_assume_role_trust_policy_document_for_ec2_entities 
trust_policy_document="${__RESULT}"

check_role_exists "${role_nm}"
role_exists="${__RESULT}"

if [[ 'false' == "${role_exists}" ]]
then
   create_role "${role_nm}" "${instance_key} role" "${trust_policy_document}" >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "${instance_key} role created."
else
   echo "WARN: ${instance_key} role already created."
fi

check_instance_profile_has_role_associated "${instance_profile_nm}" "${role_nm}" 
is_role_associated="${__RESULT}"

if [[ 'false' == "${is_role_associated}" ]]
then
   echo 'Associating role to instance profile ...'
   
   associate_role_to_instance_profile "${instance_profile_nm}" "${role_nm}"

   echo 'Role associated to the instance profile.'
else
   echo 'WARN: role already associated to the instance profile.'
fi 
  
echo    
echo "${instance_key} box permissions configured."
echo

