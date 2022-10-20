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
