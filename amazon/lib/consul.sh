#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: consul.sh
#   DESCRIPTION: Consul commands.
#       GLOBALS: None
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#===============================================================================

#===============================================================================
# Restart Consul service with systemd.
#
# Globals:
#  None
# Arguments:
# +service_nm -- systemd service name.
# Returns:      
#  None 
#===============================================================================
function consul_restart_service()
{
   local exit_code=0

   systemctl daemon-reload
   systemctl restart 'consul' 
   systemctl status 'consul' 
   consul version
            
   return "${exit_code}"
}

#===============================================================================
# Verifies if Consul is started, waits 60 seconds if not.
#
# Globals:
#  None
# Arguments:
# +service_nm -- systemd service name.
# Returns:      
#  None 
#===============================================================================
function consul_verify_and_wait()
{
   __RESULT='false'
   local exit_code=0
   
   # shellcheck disable=SC2015
   consul members && echo "Consul is running." || 
   {
      echo "Waiting for Consul" 
      
      wait 30
   
      # shellcheck disable=SC2015
      consul members && echo "Consul is running." || 
      {
         echo "WARN: Consul not answering after 30 sec."
         
         __RESULT='false'
         
         return 0
      }
   }
  
   # shellcheck disable=SC2034 
   __RESULT='true' 
   
   return "${exit_code}"
}

#===============================================================================
# Adds a key in Consul's key value store.
#
# Globals:
#  None
# Arguments:
# +key_nm    -- key name.
# +key_value -- key value.
# Returns:      
#  None 
#===============================================================================
function consul_put_key()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   local exit_code=0
   local -r key_nm="${1}"  
   local -r key_value="${2}"  
   
   consul kv put "${key_nm}" "${key_value}"
   
   return "${exit_code}"
}

#===============================================================================
# Returns a key stored in Consul's key value store.
#
# Globals:
#  None
# Arguments:
# +key_nm -- key name.
# Returns:      
#  the key value in the __RESULT varialble 
#===============================================================================
function consul_get_key()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   __RESULT=''
   local exit_code=0
   local -r key_nm="${1}"  
   local key_value=''
   
   key_value="$(consul kv get "${key_nm}")"
   
   # shellcheck disable=SC2034 
   __RESULT="${key_value}"
   
   return "${exit_code}"
}
