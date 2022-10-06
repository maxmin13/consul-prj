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
logfile_nm="${instance_key}".log

####
STEP "${instance_key} image"
####

get_instance "${instance_key}" 'TargetImageName'
image_nm="${__RESULT}" 
get_image_id "${image_nm}"
image_id="${__RESULT}"

if [[ -z "${image_id}" ]]
then
   echo "* WARN: ${instance_key} image not found."
else
   get_image_state "${image_nm}"
   image_st="${__RESULT}"
   
   echo "* ${instance_key} image ID: ${image_id} (${image_st})."
fi

get_image_snapshot_ids "${image_nm}"
snapshot_ids="${__RESULT}"

if [[ -z "${snapshot_ids}" ]]
then
   echo "* WARN: ${instance_key} image snapshots not found."
else
   echo "* ${instance_key} image snapshot IDs: ${snapshot_ids}."
fi

echo

## 
## Image.
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

