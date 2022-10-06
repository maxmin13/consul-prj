#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: datacenter_consts_utils.sh
#   DESCRIPTION: The script contains general Bash functions.
#       GLOBALS: None
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#
#   Retrieve the values in datacenter_consts.json file.
#
#===============================================================================

function get_datacenter()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r property_nm="${1}"
   local property_val=''
   
   # shellcheck disable=SC2002
   property_val=$(cat "${LIBRARY_DIR}"/constants/datacenter_consts.json | 
   	jq -r --arg property "${property_nm}" -c '.Datacenter[$property]')

   __RESULT="${property_val}"
   
   return "${exit_code}"
}

function get_instance()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r instance_key="${1}"
   local -r property_nm="${2}"
   local property_val=''
   
   # shellcheck disable=SC2002
   property_val=$(cat "${LIBRARY_DIR}"/constants/datacenter_consts.json | 
   	jq -r --arg key "${instance_key}" -c '.Datacenter.Instances[] | select(.Key | index($key))' |
   	      jq -r --arg property "${property_nm}" -c '.[$property]')   
   
   __RESULT="${property_val}"
   
   return "${exit_code}"
}

function get_application()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r instance_key="${1}"
   local -r application_nm="${2}"
   local -r property_nm="${3}"
   local property_val=''
   
   # shellcheck disable=SC2002
   property_val=$(cat "${LIBRARY_DIR}"/constants/datacenter_consts.json | 
   	jq -r --arg key "${instance_key}" -c '.Datacenter.Instances[] | select(.Key | index($key))' |
   	   jq -r --arg name "${application_nm}" -c '.Applications[] | select(.Name | index($name))' |
   	      jq -r --arg property "${property_nm}" -c '.[$property]')
   
   # shellcheck disable=SC2034
   __RESULT="${property_val}"
   
   return "${exit_code}"
}

function get_application_port()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r instance_key="${1}"
   local -r application_key="${2}"
   local -r property_nm="${3}"
   local property_val=''

   get_application "${instance_key}" "${application_key}" "Port"
   # shellcheck disable=SC2086
   property_val=$(echo $__RESULT | jq -r --arg property "${property_nm}" -c '.[$property]') 

   # shellcheck disable=SC2034
   __RESULT="${property_val}"
   
   return "${exit_code}"
}

function get_application_config()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r instance_key="${1}"
   local -r instance_key="${2}"
   local -r property_nm="${3}"
   local property_val=''

   get_application "${instance_key}" "${instance_key}" "Config"
   # shellcheck disable=SC2086
   property_val=$(echo $__RESULT | jq -r --arg property "${property_nm}" -c '.[$property]') 

   # shellcheck disable=SC2034
   __RESULT="${property_val}"
   
   return "${exit_code}"
}
