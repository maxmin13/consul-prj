#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: general_utils.sh
#   DESCRIPTION: The script contains general Bash functions.
#       GLOBALS: None
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#===============================================================================

#===============================================================================
# Parses a string and escape the characters that are special characters for 
# 'sed' program.
# Replaces:
#          each '/' with '\/'
# Globals:
#  None
# Arguments:
# +str         -- The string to be parsed.
# Returns:      
#  the escaped string.  
#===============================================================================
function escape()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments'
      return 1
   fi
   
   local str="${1}"
   local escaped_str
   
   # '/' to '\/'
   escaped_str="$(echo "${str}" | sed  -e 's/\//\\\//g')"
 
   echo "${escaped_str}"
}

#===============================================================================
# Makes the program sleep for a number of seconds.
# Globals:
#  None
# Arguments:
# +seconds -- the number of seconds the program sleeps.
# Returns:      
#  None.  
#===============================================================================
function wait()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments'
      return 1
   fi
   
   local seconds="${1}"
   local count=0
   
   while [[ "${count}" -lt "${seconds}" ]]; do
      printf '.'
      sleep 1
      count=$((count+1))
   done
   
   printf '\n'
   
   return 0
}

function get_aws_access_key_id()
{
   __RESULT=''
   local exit_code=0
   local key_value=''
   
   __get_aws_key 'aws_access_key_id'
   key_value="${__RESULT}"

   __RESULT="${key_value}"
   
   return "${exit_code}"
}

function get_aws_secret_access_key()
{
   __RESULT=''
   local exit_code=0
   local key_value=''
   
   __get_aws_key 'aws_secret_access_key'
   key_value="${__RESULT}"

   __RESULT="${key_value}"
   
   return "${exit_code}"
}

function __get_aws_key()
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
   
   key_value=$(awk -v key="${key_nm}" -F' *= *' '$1 == key {print $2}' ~/.aws/credentials)

   __RESULT="${key_value}"
   
   return "${exit_code}"
}

function STEP() 
{ 
   echo ; 
   echo ; 
   echo "==\\" ;
   echo "===>" "$@" ; 
   echo "==/" ; 
   echo ; 
}




