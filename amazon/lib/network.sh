#!/usr/bin/bash

set -o errexit
## turn on -e in subshells
## shopt -s inherit_errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: network.sh
#   DESCRIPTION: network ip commands.
#       GLOBALS: None
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#===============================================================================

#===============================================================================
# Checks if a network interface exists.
#
# Globals:
#  None
# Arguments:
# +network_nm -- network name.
# Returns:      
#  true/false in the __RESULT variable.
#===============================================================================
function ip_check_network_interface_exists()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   __RESULT='false'
   local exit_code=0
   local -r network_nm="${1}"  
   local name=''

   # check at the network layer if a device exists (if a device with an IP 
   # address has been created).
   name="$(ip address | awk -v nm="${network_nm}" '$2~nm {print $2}')"
   
   # shellcheck disable=SC2034
   if [[ -n "${name}" ]]
   then
      __RESULT='true'
   else
      __RESULT='false'
   fi
      
   return "${exit_code}"
}

function ip_delete_network_interface()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r network_nm="${1}"  
   
   ip link delete dev "${network_nm}"
      
   return "${exit_code}"
}
