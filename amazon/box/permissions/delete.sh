#!/bin/bash

# shellcheck disable=SC2015

#####################################################
# Deletes the instance profile of a box.
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

get_datacenter_instance "${instance_key}" 'Name'
instance_nm="${__RESULT}"
ec2_instance_is_running "${instance_nm}"
is_running="${__RESULT}"
ec2_get_instance_state "${instance_nm}"
instance_st="${__RESULT}"

if [[ 'true' == "${is_running}" ]]
then
   echo "* ${instance_key} box ready (${instance_st})."
else
   if [[ -n "${instance_st}" ]]
   then
      echo "* WARN: ${instance_key} box is not ready (${instance_st})."
   else
      echo "* WARN: ${instance_key} box is not ready."
   fi
fi

get_datacenter_instance "${instance_key}" 'InstanceProfileName'
profile_nm="${__RESULT}"
iam_check_instance_profile_exists "${profile_nm}"
profile_exists="${__RESULT}"

if [[ 'true' == "${profile_exists}" ]]
then
   iam_get_instance_profile_id "${profile_nm}" 
   profile_id="${__RESULT}"

   echo "* ${instance_key} instance profile ID: ${profile_id}"
else
   echo '* WARN: instance profile not found.'
fi

get_datacenter_instance "${instance_key}" 'RoleName'
role_nm="${__RESULT}"
iam_check_role_exists "${role_nm}"
role_exists="${__RESULT}"

if [[ 'true' == "${role_exists}" ]]
then
   iam_get_role_arn "${role_nm}" >> "${LOGS_DIR}"/"${logfile_nm}"
   role_arn="${__RESULT}"

   echo "* ${instance_key} role ARN: ${role_arn}"
else
   echo "* WARN: ${instance_key} role not found."
fi

echo

#
# Permissions.
#

if [[ 'true' == "${role_exists}" ]]
then
   echo 'Deleting role ...'
   
   iam_delete_role "${role_nm}" >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo 'Role deleted.'
else
   echo 'WARN: role already deleted.'
fi

if [[ 'true' == "${profile_exists}" ]]
then
   echo 'Deleting instance profile ...'

   iam_ec2_delete_instance_profile "${profile_nm}" >> "${LOGS_DIR}"/"${logfile_nm}"

   echo 'Instance profile deleted.'
else
   echo 'WARN: instance profile already deleted.'
fi

echo  
echo "${instance_key} box permissions deleted."
echo

