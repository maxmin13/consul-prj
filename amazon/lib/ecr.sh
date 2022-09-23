#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: ecr.sh
#   DESCRIPTION: Amazon  Elastic  Container Registry (Amazon ECR) is a managed 
#                container image registry service.
#       GLOBALS: None
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#===============================================================================

#===============================================================================
# Checks if an ECR repository exists.
# 
# Globals:
#  None
# Arguments:
# +repository_nm -- the repository name.
# +region_nm     -- the region name.
# Returns:      
#  true/false in the __RESULT variable.  
#===============================================================================
function ecr_check_repository_exists()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT='false'
   local exit_code=0
   local -r repository_nm="${1}"
   local -r region_nm="${2}"
   
   set +e
   
   # the command throws 254 error if the repository is not found.
   aws ecr describe-repositories \
       --repository-names "${repository_nm}" \
       --region "${region_nm}"
              
   exit_code=$?           
   set -e

   if [[ 0 -ne "${exit_code}" && 254 -ne "${exit_code}" ]]
   then
      echo 'ERROR: checking ECR repository.'
      
      return "${exit_code}"
      
   elif [[ 0 -eq "${exit_code}" ]] 
   then
      __RESULT='true'
      
   elif [[ 254 -eq "${exit_code}" ]] 
   then
      # catch not found error and return false.
      __RESULT='false'
      
      exit_code=0
   fi
          
   return "${exit_code}"           
}

#===============================================================================
# Creates an Amazon ECR repository.
#
# Globals:
#  None
# Arguments:
# +repository_nm -- the repository name.
# +region_nm     -- the region name.
# Returns:      
#  none.  
#===============================================================================
function ecr_create_repository()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
  
   local exit_code=0
   local -r repository_nm="${1}"
   local -r region_nm="${2}"
   
   aws ecr create-repository \
      --repository-name "${repository_nm}" \
      --region "${region_nm}"  
      
   exit_code=$?     
      
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: creating repository.'
   fi    
                       
   return "${exit_code}"
}

#===============================================================================
# Deletes an Amazon ECR repository.
#
# Globals:
#  None
# Arguments:
# +repository_nm -- the repository name.
# +region_nm     -- the region name.
# Returns:      
#  none.  
#===============================================================================
function ecr_delete_repository()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
  
   local exit_code=0
   local -r repository_nm="${1}"
   local -r region_nm="${2}"
       
   aws ecr delete-repository --repository-name "${repository_nm}" \
      --region "${region_nm}" \
      --force   
       
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting repository.'
   fi     
            
   return "${exit_code}"
}

function ecr_get_login_pwd()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   __RESULT=''
   local exit_code=0
   local -r region_nm="${1}"
   local login_pwd=''
   
   login_pwd="$(aws ecr get-login-password --region "${region_nm}")"
   
   __RESULT="${login_pwd}"
     
   return "${exit_code}"
}

function ecr_get_registry_uri()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   __RESULT=''
   local -r region_nm="${1}"
   local aws_account_id=''
   local registry_uri=''
   
   aws_account_id=$(aws sts get-caller-identity --query 'Account' --output text)
   registry_uri="${aws_account_id}.dkr.ecr.${region_nm}.amazonaws.com"
   
   __RESULT="${registry_uri}"
   
   return 0
}

function ecr_get_repostory_uri()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r repository_nm="${1}"
   local -r registry_uri="${2}"

   # shellcheck disable=SC2034
   __RESULT="${registry_uri}"/"${repository_nm}"
   
   return "${exit_code}"
}


