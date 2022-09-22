#!/usr/bin/bash

set -o errexit
## turn on -e in subshells
##shopt -s inherit_errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: secretmanager.sh
#   DESCRIPTION: the script contains functions that use AWS client to make 
#                calls to AWS Secrets Manager.
#       GLOBALS: None
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#===============================================================================

#===============================================================================
# Creates a secret as a Json key/value object in the current account.
#
# Globals:
#  None
# Arguments:
# +secret_nm  -- the name of the secret.
# +region     -- the region of the secret.
# +key        -- the secret's key. 
# +value      -- the secret's value.

# Returns:      
#  none.  
#===============================================================================
function sm_create_secret()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r secret_nm="${1}"
   local -r region="${2}"
   # shellcheck disable=SC2034
   local -r key="${3}"
   # shellcheck disable=SC2034
   local -r value="${4}"
   local secret_file=''

   secret_file=$(cat <<-EOF
	{
		"Key": "${key}",
		"Value": "${value}"
	}      
	EOF
   )   

   aws secretsmanager create-secret --region "${region}" --name "${secret_nm}" \
      --secret-string "${secret_file}"

   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: creating the secret.'
   fi 
   
   return "${exit_code}"
}

#===============================================================================
# Deletes a secret stored in the current account.
#
# Globals:
#  None
# Arguments:
# +secret_nm -- the name of the secret.
# Returns:      
#  none
#===============================================================================
function sm_delete_secret()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r secret_nm="${1}"
   local -r region="${2}"
   local secret;
   
   aws secretsmanager delete-secret --force-delete-without-recovery \
      --secret-id "${secret_nm}" --region "${region}"

   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting the secret.'
   fi 
   
   return "${exit_code}"
}

#===============================================================================
# Retrieves a secret stored in the current account.
#
# Globals:
#  None
# Arguments:
# +secret_nm -- the name of the secret.
# +region    -- the region of the secret.
# Returns:      
#  the secret, in the __RESULT variable.  
#===============================================================================
function sm_get_secret()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r secret_nm="${1}"
   local -r region="${2}"
   local secret;
   
   secret="$(aws secretsmanager get-secret-value --region "${region}" --secret-id "${secret_nm}"| jq --raw-output '.SecretString' | jq -r .Value)"
         
   __RESULT="${secret}"
   
   return "${exit_code}"
}

#===============================================================================
# Checks if a secret exists in the current account.
#
# Globals:
#  None
# Arguments:
# +secret_nm -- the name of the secret.
# +region    -- the region of the secret.
# Returns:      
#  true/false in the global __RESULT variable.  
#===============================================================================
function sm_check_secret_exists()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT='false'
   local exit_code=0
   local -r secret_nm="${1}"
   local -r region="${2}"
   local secret_desc=''

   secret_desc="$(aws secretsmanager describe-secret --secret-id "${secret_nm}" \
      --region "${region}" --output text)"          
   
   # shellcheck disable=SC2034
   if [[ -n "${secret_desc}" ]]
   then
      __RESULT='true'
   else
      __RESULT='false'
   fi 
   
   return "${exit_code}"
}

