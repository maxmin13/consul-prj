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
   	jq -r --arg property "${property_nm}" -c '.Datacenter[$property] // empty')

   __RESULT="${property_val}"
   
   return "${exit_code}"
}

function get_datacenter_instance()
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
   	      jq -r --arg property "${property_nm}" -c '.[$property] // empty')   
   
   __RESULT="${property_val}"
   
   return "${exit_code}"
}

function get_datacenter_instance_admin()
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
   
   get_datacenter_instance 'admin-instance' "${property_nm}"
   property_val="${__RESULT}"

   __RESULT="${property_val}"
   
   return "${exit_code}"
}

function get_datacenter_network()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r network_key="${1}"
   local -r property_nm="${2}"
   local property_val=''
   
   # shellcheck disable=SC2002
   property_val=$(cat "${LIBRARY_DIR}"/constants/datacenter_consts.json | 
   	jq -r --arg network "${network_key}" -c '.Datacenter.Networks[] | select(.Key | index($network))' |
   	      jq -r --arg property "${property_nm}" -c '.[$property] // empty')   
   
   __RESULT="${property_val}"
   
   return "${exit_code}"
}

function get_datacenter_application()
{
   if [[ $# -lt 3 ]]
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
   
   # shellcheck disable=SC2002
   property_val=$(cat "${LIBRARY_DIR}"/constants/datacenter_consts.json | 
   	jq -r --arg instancekey "${instance_key}" -c '.Datacenter.Instances[] | select(.Key | index($instancekey))' |
   	   jq -r --arg applicationKey "${application_key}" -c '.Applications[] | select(.Key | index($applicationKey))' |
   	      jq -r --arg property "${property_nm}" -c '.[$property] // empty')
   
   # shellcheck disable=SC2034
   __RESULT="${property_val}"
   
   return "${exit_code}"
}

function get_datacenter_application_port()
{
   if [[ $# -lt 3 ]]
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

   get_datacenter_application "${instance_key}" "${application_key}" 'Port'
   # shellcheck disable=SC2086
   property_val=$(echo $__RESULT | jq -r --arg property "${property_nm}" -c '.[$property] // empty') 

   # shellcheck disable=SC2034
   __RESULT="${property_val}"
   
   return "${exit_code}"
}

function get_datacenter_application_client_interface()
{
   if [[ $# -lt 3 ]]
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

   __get_datacenter_application_interface "${instance_key}" "${application_key}" 'ClientInterface' "${property_nm}"

   return "${exit_code}"
}

function get_datacenter_application_bind_interface()
{
   if [[ $# -lt 3 ]]
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

   __get_datacenter_application_interface "${instance_key}" "${application_key}" 'BindInterface' "${property_nm}"

   return "${exit_code}"
}

function get_datacenter_application_consul_interface()
{
   if [[ $# -lt 3 ]]
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

   __get_datacenter_application_interface "${instance_key}" "${application_key}" 'ConsulInterface' "${property_nm}"

   return "${exit_code}"
}

function get_datacenter_application_advertise_interface()
{
   if [[ $# -lt 3 ]]
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

   __get_datacenter_application_interface "${instance_key}" "${application_key}" 'AdvertiseInterface' "${property_nm}"

   return "${exit_code}"
}

function __get_datacenter_application_interface()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r instance_key="${1}"
   local -r application_key="${2}"
   local -r interface_nm="${3}"
   local -r property_nm="${4}"
   local property_val=''

   get_datacenter_application "${instance_key}" "${application_key}" "${interface_nm}"

   # shellcheck disable=SC2086
   property_val=$(echo "${__RESULT}" | jq -r --arg property "${property_nm}" -c '.[$property] // empty') 

   # shellcheck disable=SC2034
   __RESULT="${property_val}"
   
   return "${exit_code}"
}

function get_datacenter_application_url()
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
   local url_val=''
   
   if [[ 3 -eq "${#}" ]]
   then
      webapp_address="${3}"
   fi
   
   if [[ 4 -eq "${#}" ]]
   then
      webapp_address="${3}"
      webapp_port="${4}"
   fi

   get_datacenter_application "${instance_key}" "${application_key}" 'Url'
   # shellcheck disable=SC2086
   url_val="${__RESULT}"
   url_val=$(sed -e "s|<address>|${webapp_address}|g" -e "s|<port>|${webapp_port}|g" <<< "${url_val}")
   
   # shellcheck disable=SC2034
   __RESULT="${url_val}"
   
   return "${exit_code}"
}
