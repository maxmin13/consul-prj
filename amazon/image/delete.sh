#!/usr/bin/bash

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
STEP "${instance_key} image"
####

logfile_nm="${instance_key}".log

#
# Get the configuration values from the file ec2_consts.json
#

get_instance_name "${instance_key}"
instance_nm="${__RESULT}"
get_security_group_name "${instance_key}"
sgp_nm="${__RESULT}"
get_target_image_name "${instance_key}"
target_image_name="${__RESULT}" 

# The temporary box used to build the image, it should be already deleted.
get_instance_id "${instance_nm}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo "* WARN: ${instance_key} box not found."
else
   get_instance_state "${instance_nm}"
   instance_st="${__RESULT}"
   
   echo "* ${instance_key} box ID: ${instance_id} (${instance_st})."
fi

# The temporary security group used to build the image, it should be already deleted.
get_security_group_id "${sgp_nm}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo "* WARN: ${instance_key} security group not found."
else
   echo "* ${instance_key} security group. ${sgp_id}."
fi

get_image_id "${target_image_name}"
image_id="${__RESULT}"

if [[ -z "${image_id}" ]]
then
   echo "* WARN: ${instance_key} image not found."
else
   get_image_state "${target_image_name}"
   image_st="${__RESULT}"
   
   echo "* ${instance_key} image ID: ${image_id} (${image_st})."
fi

get_image_snapshot_ids "${target_image_name}"
snapshot_ids="${__RESULT}"

if [[ -z "${snapshot_ids}" ]]
then
   echo "* WARN: ${instance_key} image snapshots not found."
else
   echo "* ${instance_key} image snapshot IDs: ${snapshot_ids}."
fi

echo

## 
## EC2 image.
## 

if [[ -n "${image_id}" ]]
then
   echo  "Deleting ${instance_key} image ..."
   
   delete_image "${image_id}" >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "${instance_key} image deleted."
fi

## 
## Image snapshots.
##

if [[ -n "${snapshot_ids}" ]]
then
   for id in ${snapshot_ids}
   do
      echo "Deleting ${instance_key} snapshot ..."
      
      delete_image_snapshot "${id}"
      
      echo "${instance_key} snapshot deleted."
   done
fi

