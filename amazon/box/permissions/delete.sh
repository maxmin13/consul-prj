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

####
STEP "${instance_key} box permissions"
####

logfile_nm="${instance_key}".log

#
# Get the configuration values from the file ec2_consts.json
#

get_instance_name "${instance_key}"
instance_nm="${__RESULT}" 
get_instance_profile_name "${instance_key}"
instance_profile_nm="${__RESULT}" 
get_role_name "${instance_key}"
role_nm="${__RESULT}"

get_instance_id "${instance_nm}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo "* WARN: ${instance_key} box not found."
fi

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${instance_nm}"
   instance_st="${__RESULT}"
   
   if [[ 'running' == "${instance_st}" ]]
   then
      echo "* ${instance_key} box ready (${instance_st})."
   else
      echo "* WARN: ${instance_key} box is not ready. (${instance_st})."
   fi
fi

check_instance_profile_exists "${instance_profile_nm}"
instance_profile_exists="${__RESULT}"

if [[ 'true' == "${instance_profile_exists}" ]]
then
   get_instance_profile_id "${instance_profile_nm}" 
   instance_profile_id="${__RESULT}"

   echo "* ${instance_key} instance profile ID: ${instance_profile_id}"
else
   echo "* WARN: ${instance_key} instance profile not found."
fi

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

if [[ 'true' == "${role_exists}" ]]
then
   echo "Deleting ${instance_key} role ..."
   
   delete_role "${role_nm}" >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "${instance_key} role deleted."
else
   echo "WARN: ${instance_key} role already deleted."
fi

if [[ 'true' == "${instance_profile_exists}" ]]
then
   echo "${instance_key} deleting instance profile ..."

   delete_instance_profile "${instance_profile_nm}" >> "${LOGS_DIR}"/"${logfile_nm}"

   echo "${instance_key} instance profile deleted."
else
   echo "WARN: ${instance_key} instance profile already deleted."
fi

  
echo  
echo "${instance_key} box permissions deleted."
echo

