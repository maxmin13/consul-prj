#!/usr/bin/bash

# shellcheck disable=SC2002

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: service_consts_utils.sh
#   DESCRIPTION: The script contains general Bash functions.
#       GLOBALS: LIBRARY_DIR lib directory.
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#
#   Retrieve the values in service_consts.json file.
#
#===============================================================================

function get_service_keys()
{
   __RESULT=''
   local exit_code=0
   local property_val=''
   
   property_val=$(cat "${LIBRARY_DIR}"/constants/service_consts.json | 
   	jq -r -c '.Docker.Services[].Key // empty')
   	
   __RESULT="${property_val}"
   
   return "${exit_code}"
}

# returns the directory containing the scripts to build the service image and
# the sources of the application.
function get_service_sources_directory()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r service_key="${1}"
   local property_val=''
   
   property_val=$(cat "${LIBRARY_DIR}"/constants/service_consts.json | 
   	jq -r --arg key "${service_key}" -c '.Docker.Services[] | select(.Key | index($key))' |
   	   jq -r -c '.SourcesDirName // empty')
   	
   __RESULT="${property_val}"
   
   return "${exit_code}"
}

function get_service_image()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r service_key="${1}"
   local -r property_nm="${2}"
   local property_val=''
   
   property_val=$(cat "${LIBRARY_DIR}"/constants/service_consts.json | 
   	jq -r --arg key "${service_key}" -c '.Docker.Services[] | select(.Key | index($key))' |
   	   jq -r --arg property "${property_nm}" -c '.Image[$property] // empty')
   	
   __RESULT="${property_val}"
   
   return "${exit_code}"
}

# used if the property is a list, to access the elements.
function get_service_image_iterate()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r service_key="${1}"
   local -r property_nm="${2}"
   local property_val=''
   
   get_service_image "${service_key}" "${property_nm}"
   # shellcheck disable=SC2086
   property_val=$(echo $__RESULT  | jq -r -c '.[]') 
   	         
   # shellcheck disable=SC2034
   __RESULT="${property_val}"
   
   return "${exit_code}"
}

function get_service_container()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r service_key="${1}"
   local -r property_nm="${2}"
   local property_val=''

   property_val=$(cat "${LIBRARY_DIR}"/constants/service_consts.json | 
   	jq -r --arg key "${service_key}" -c '.Docker.Services[] | select(.Key | index($key))' |
   	      jq -r --arg property "${property_nm}" -c '.Container[$property] // empty')

   # shellcheck disable=SC2034
   __RESULT="${property_val}"
   
   return "${exit_code}"
}

# used if the property is a list, to access the elements.
function get_service_container_iterate()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r service_key="${1}"
   local -r property_nm="${2}"
   local property_val=''
   
   get_service_container "${service_key}" "${property_nm}"
   # shellcheck disable=SC2086
   property_val=$(echo $__RESULT  | jq -r -c '.[]') 
   	         
   # shellcheck disable=SC2034
   __RESULT="${property_val}"
   
   return "${exit_code}"
}

function get_service_volume()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r service_key="${1}"
   local -r property_nm="${2}"
   local property_val=''

   get_service_container "${service_key}" "Volume"
   # shellcheck disable=SC2086
   property_val=$(echo $__RESULT | jq -r --arg property "${property_nm}" -c '.[$property]') 

   # shellcheck disable=SC2034
   __RESULT="${property_val}"
   
   return "${exit_code}"
}

# command to run at container start-up.
function get_service_command()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r service_key="${1}"
   local deploy_dir=''
   local property_val=''
   
   if [[ 2 -eq "${#}" ]]
   then
      deploy_dir="${2}"
   fi
   
   get_service_container "${service_key}" "Cmd"
   # shellcheck disable=SC2086
   property_val="${__RESULT}"
   # shellcheck disable=SC2001
   property_val=$(sed "s|<deploy_dir>|${deploy_dir}|g" <<< "${property_val}")
   
   # shellcheck disable=SC2034
   __RESULT="${property_val}"
   
   return "${exit_code}"
}

function get_service_port()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r service_key="${1}"
   local -r property_nm="${2}"
   local property_val=''

   get_service_container "${service_key}" "Port"
   # shellcheck disable=SC2086
   property_val=$(echo $__RESULT | jq -r --arg property "${property_nm}" -c '.[$property]') 

   # shellcheck disable=SC2034
   __RESULT="${property_val}"
   
   return "${exit_code}"
}

function get_service_deploy()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r service_key="${1}"
   local -r property_nm="${2}"
   local property_val=''

   get_service_container "${service_key}" "Deploy"
   # shellcheck disable=SC2086
   property_val=$(echo $__RESULT | jq -r --arg property "${property_nm}" -c '.[$property]') 

   # shellcheck disable=SC2034
   __RESULT="${property_val}"
   
   return "${exit_code}"
}

# container application's url.
function get_service_webapp_url()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r service_key="${1}"
   local webapp_address=''
   local webapp_port=''
   local url_val=''
   
   if [[ 2 -eq "${#}" ]]
   then
      webapp_address="${2}"
   fi
   
   if [[ 3 -eq "${#}" ]]
   then
      webapp_address="${2}"
      webapp_port="${3}"
   fi

   get_service_deploy "${service_key}" "WebappUrl"
   # shellcheck disable=SC2086
   url_val="${__RESULT}"
   url_val=$(sed -e "s|<address>|${webapp_address}|g" -e "s|<port>|${webapp_port}|g" <<< "${url_val}")
   
   # shellcheck disable=SC2034
   __RESULT="${url_val}"
   
   return "${exit_code}"
}

