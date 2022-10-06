#!/usr/bin/bash

####################################################################################
# makes a secure linux box image:
# hardened, ssh on 38142.
# No root access to the instance.
# Remove the ec2-user default user and 
# creates the shared-user user.
####################################################################################

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

if [[ -n "${image_id}" ]]
then
   # If the image is in 'terminated' state, it takes about an hour to disappear,
   # to create a new image you have to change the name.
   
   get_image_state "${image_nm}"
   image_st="${__RESULT}"
   
   if [[ -n "${image_st}" ]]
   then
      echo "* WARN: the image is already created (${image_st})"
      
      return 0
   fi
fi

# Create an image based on an previously created instance.
# Amazon EC2 powers down the instance before creating the AMI to ensure that everything on the 
# instance is stopped and in a consistent state during the creation process.

get_instance "${instance_key}" 'Name'
instance_nm="${__RESULT}"
get_instance_id "${instance_nm}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo "* ERROR: ${instance_key} box not found."
   exit 1
else
   get_instance_state "${instance_nm}"
   instance_st="${__RESULT}"
   
   echo "* ${instance_key} box ID: ${instance_id} (${instance_st})."
fi

echo

## 
## Instance.
## 

# Stop the instance before creating the image, to ensure data integrity.

echo "Stopping ${instance_key} box ..."

stop_instance "${instance_id}" >> "${LOGS_DIR}"/"${logfile_nm}" 

echo "${instance_key} box stopped." 

## 
## Image.
## 

echo "Creating ${instance_key} image ..."

create_image "${instance_id}" "${image_nm}" "${image_nm}" >> "${LOGS_DIR}"/"${logfile_nm}"	

echo
echo "${instance_key} image created."
echo

