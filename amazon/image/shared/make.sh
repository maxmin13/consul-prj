#!/usr/bin/bash

##########################################
# makes a secure linux box image:
# hardened, ssh on 38142.
# No root access to the instance.
# Remove the ec2-user default user and 
# creates the shared-user user.
##########################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#
STEP 'Shared image'
#

shared_dir='shared'

get_datacenter_id "${DTC_NM}"
dtc_id="${__RESULT}"
  
if [[ -z "${dtc_id}" ]]
then
   echo '* ERROR: data center not found.'
   exit 1
else
   echo "* data center ID: ${dtc_id}."
fi

get_image_id "${SHARED_IMG_NM}"
image_id="${__RESULT}"

if [[ -n "${image_id}" ]]
then
   get_image_state "${SHARED_IMG_NM}"
   image_st="${__RESULT}"
   
   if [[ 'available' == "${image_st}" ]]
   then
      echo "* WARN: the image is already created (${image_st})"
      echo
      return
   else
      # This is the case the image is in 'terminated' state, it takes about an hour to disappear,
      # if you want to create a new image you have to change the name.
      echo "* ERROR: the image is already created (${image_st})" 
      exit 1  
   fi
fi

# Create an image based on an previously created instance.
# Amazon EC2 powers down the instance before creating the AMI to ensure that everything on the 
# instance is stopped and in a consistent state during the creation process.

get_instance_id "${SHARED_INST_NM}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* ERROR: box not found.'
   exit 1
else
   get_instance_state "${SHARED_INST_NM}"
   instance_st="${__RESULT}"
   
   echo "* box ID: ${instance_id} (${instance_st})."
fi

echo

# Removing old files
rm -rf "${TMP_DIR:?}"/"${shared_dir}"
mkdir "${TMP_DIR}"/"${shared_dir}"

## 
## Shared image.
## 

echo 'Creating the image ...'

create_image "${instance_id}" "${SHARED_IMG_NM}" "${SHARED_IMG_DESC}" | logto shared.log	

# Removing old files
rm -rf "${TMP_DIR:?}"/"${shared_dir}"

echo
echo 'Image created.'

