#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: log_utils.sh
#   DESCRIPTION: The script contains general Bash functions.
#       GLOBALS: None
#
#===============================================================================

#===============================================================================
# Redirect the standard input to a file. If LOGS_DIR variable is defined, the
# log file is saved there, otherwise in /var/log and root level access is 
# required.
#
# Globals:
#  None
# Arguments:
# +file -- log file.
# Returns:      
#  None  
#===============================================================================
function logto()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments'
      return 128
   fi
   
   local exit_code=0
   local -r file="${1}"
   local dir=/var/log
   
   set +e  
   if [[ -n ${LOGS_DIR+x} ]]
   then 
      dir="${LOGS_DIR}"/"$(date +%Y%m%d)"
      mkdir -p "${dir}"
   fi
   
   exit_code=$?
   
   if [[ 0 -lt "${exit_code}" ]]
   then
      echo 'ERROR: ** log error **'
   fi
 
   cat | awk -v dte="$(date +%Y%m%d:%H%M%S)" '{printf "%s\t%s\n", dte, $1}' >> "${dir}/${file}"
   
   exit_code=$?
   
   if [[ 0 -lt "${exit_code}" ]]
   then
      echo 'ERROR: ** log error **'
   fi
   
   set -e
        
   return 0
}

