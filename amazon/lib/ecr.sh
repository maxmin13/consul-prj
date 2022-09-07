#!/usr/bin/bash

set -o errexit
## turn on -e in subshells
## shopt -s inherit_errexit
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
# Checks if a repository exists.
# The command throws a 254 error if the repository isn't found.
#
# Globals:
#  None
# Arguments:
# +repository_nm -- the repository name.
# Returns:      
#  true/false in the global __RESULT variable.  
#===============================================================================
function ecr_check_repository_exists()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r repository_nm="${1}"
   local repository_desc=''
   local exists='false'

   # error if repository not found.
   repository_desc="$(aws ecr describe-repositories \
              --repository-names "${repository_nm}" \
              --region "${DTC_REGION}" \
              --query repositories[0].repositoryArn \
              --output text)"          
   
   if [[ -n "${repository_desc}" ]]
   then
      exists='true'
   fi 

   __RESULT="${exists}"
   
   return "${exit_code}"
}

#===============================================================================
# Creates an Amazon ECR repository.
#
# Globals:
#  None
# Arguments:
# +repository_nm -- the repository name.
# Returns:      
#  none.  
#===============================================================================
function ecr_create_repository()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
  
   local exit_code=0
   local -r repository_nm="${1}"
       
   aws ecr create-repository \
      --repository-name "${repository_nm}" \
      --region "${DTC_REGION}"   
                       
   return "${exit_code}"
}

#===============================================================================
# Deletes an Amazon ECR repository.
#
# Globals:
#  None
# Arguments:
# +repository_nm -- the repository name.
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
       
   aws ecr delete-repository --repository-name "${repository_nm}" \
      --region "${DTC_REGION}" \
      --force   
       
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting repository.'
      return "${exit_code}"
   fi     
            
   return "${exit_code}"
}

#===============================================================================
# Checks if an image exists in an ECR repository.
# The command throws an error if the repository or the image not found.
#
# Globals:
#  None
# Arguments:
# +repository_nm -- the ECR repository name that hosts the image.
# +img_tag       -- the the tag associated with the image in the ECR repository.
# Returns:      
#  true/false in the global __RESULT variable.  
#===============================================================================
function ecr_check_img_exists()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r repository_nm="${1}"
   local -r img_tag="${2}"
   local image_desc=''
   local exists='false'

   # the command throws an error if repository or image not found.
   image_desc="$(aws ecr describe-images \
              --repository-name "${repository_nm}" \
              --region "${DTC_REGION}" \
              --image-ids imageTag="${img_tag}" \
              --query text)"      
   
   if [[ -n "${image_desc}" ]]
   then
      exists='true'
   fi 

   __RESULT="${exists}"
   
   return "${exit_code}"
}

function ecr_get_login_pwd()
{
   __RESULT=''
   local exit_code=0
   local login_pwd=''
   
   login_pwd="$(aws ecr get-login-password --region "${DTC_REGION}")"
   
   __RESULT="${login_pwd}"
     
   return "${exit_code}"
}

function ecr_get_registry_uri()
{
   __RESULT=''
   local aws_account_id=''
   local registry_uri=''
   
   aws_account_id=$(aws sts get-caller-identity --query 'Account' --output text)
   registry_uri="${aws_account_id}.dkr.ecr.${DTC_REGION}.amazonaws.com"
   
   __RESULT="${registry_uri}"
   
   return 0
}

function ecr_get_repostory_uri()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r repository_nm="${1}"
   local registry_uri=''
   local repository_uri=''
 
   ecr_get_registry_uri
   registry_uri="${__RESULT}"

   __RESULT="${registry_uri}"/"${repository_nm}"
   
   return "${exit_code}"
}


