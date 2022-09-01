#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#
STEP 'Shared image'
#

shared_dir='shared'

# The temporary box used to build the image, it should be already deleted.
get_instance_id "${SHARED_INST_NM}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: box not found.'
else
   get_instance_state "${SHARED_INST_NM}"
   instance_st="${__RESULT}"
   
   echo "* box ID: ${instance_id} (${instance_st})."
fi

# The temporary security group used to build the image, it should be already deleted.
get_security_group_id "${SHARED_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: security group not found.'
else
   echo "* security group. ${sgp_id}."
fi

get_image_id "${SHARED_IMG_NM}"
image_id="${__RESULT}"

if [[ -z "${image_id}" ]]
then
   echo '* WARN: image not found.'
else
   get_image_state "${SHARED_IMG_NM}"
   image_st="${__RESULT}"
   
   echo "* image ID: ${image_id} (${image_st})."
fi

get_image_snapshot_ids "${SHARED_IMG_NM}"
snapshot_ids="${__RESULT}"

if [[ -z "${snapshot_ids}" ]]
then
   echo '* WARN: image snapshots not found.'
else
   echo "* image snapshot IDs: ${snapshot_ids}."
fi

echo

## 
## Shared image.
## 

if [[ -n "${image_id}" ]]
then
   echo 'Deleting image ...'
   
   delete_image "${image_id}" | logto sinatra.log
   
   echo 'Image deleted.'
fi

## 
## Image snapshots.
##

if [[ -n "${snapshot_ids}" ]]
then
   for id in ${snapshot_ids}
   do
      echo "Deleting snapshot ..."
      
      delete_image_snapshot "${id}"
      
      echo 'Snapshot deleted.'
   done
fi

