#!/usr/bin/bash

set -o errexit
## turn on -e in subshells
## shopt -s inherit_errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: network.sh
#   DESCRIPTION: network commands.
#       GLOBALS: None
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#===============================================================================

#===============================================================================
# Creates a virtual network interface, attaches an address to it and starts it.
#
# Globals:
#  None
# Arguments:
# +name       -- interface name.
# +ip_address -- interface IP address.
# +type       -- interface type.
# Returns:      
#  None 
#===============================================================================
function create_network_interface()
{
if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   local exit_code=0
   local name="${1}"
   local ip_address="${2}"
   local type="${3}"

   ip link add "${name}" type "${type}"
   ip addr add "${ip_address}" dev "${name}" 
   ip link set "${name}" up   
            
   return "${exit_code}"
}


#===============================================================================
# Checks if a network interface exists.
#
# Globals:
#  None
# Arguments:
# +name -- interface name.
# Returns:      
#  true/false in the __RESULT variable.
#===============================================================================
function check_network_interface_exists()
{
if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   __RESULT='false'
   local exit_code=0
   local -r interface_nm="${1}"  
   local exists='false'
   local name=''

   name="$(ip link | awk -v nm="${interface_nm}" '$2~nm {print $2}')"
   
   if [[ -n "${name}" ]]
   then
      exists='true'
   fi

   # shellcheck disable=SC2034  
   __RESULT="${exists}"
            
   return "${exit_code}"
}
