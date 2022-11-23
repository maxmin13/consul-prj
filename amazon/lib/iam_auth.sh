#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: iam_auth.sh
#   DESCRIPTION: The script contains functions that use AWS client to make 
#                calls to AWS Identity and Access Management (IAM).
#       GLOBALS: None
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#===============================================================================

#===============================================================================
# Builds the permission policy document to allow an entity to create, list and 
# retrieve a secret from AWS Secretsmanager.
#
# Globals:
#  None
# Arguments:
#  None
# Returns:      
#  The policy JSON document in the __RESULT global variable.  
#===============================================================================
function iam_build_secretsmanager_permission_policy_document()
{
   __RESULT=''
   local policy_document=''

   policy_document=$(cat <<-EOF
	{
		"Version": "2012-10-17",
		"Statement": [
			{
			"Effect": "Allow",
			"Action": [
				"secretsmanager:CreateSecret",
				"secretsmanager:DeleteSecret",
				"secretsmanager:ListSecrets",
				"secretsmanager:DescribeSecret",
				"secretsmanager:GetSecretValue"
			],
			"Resource": "*"
			}
		]
	}      
	EOF
   )
    
   __RESULT="${policy_document}"
   
   return 0
}

#===============================================================================
# Creates a permission policy.
#
# Globals:
#  None
# Arguments:
# +policy_nm -- the policy name.
# +policy_doc -- JSON policy document with the content for the new policy.
# Returns:      
#  none.  
#===============================================================================
function iam_create_permission_policy()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r policy_nm="${1}"
   local -r policy_doc="${2}"
    
   aws iam create-policy --policy-name "${policy_nm}" --policy-document "${policy_doc}"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: creating permission policy.'     
   fi 
   
   return "${exit_code}" 
}

#===============================================================================
# Deletes a permission policy.
#
# Globals:
#  None
# Arguments:
# +policy_nm -- the policy name.
# Returns:      
#  none.  
#===============================================================================
function iam_delete_permission_policy()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r policy_nm="${1}"
   local policy_arn;
   
   iam_get_permission_policy_arn "${policy_nm}"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleteing permission policy.' 
      return "${exit_code}"
   fi 
   
   policy_arn="${__RESULT}"
   
   if [[ -z "${policy_arn}" ]] 
   then
      echo 'Permission policy not found.'
      exit 1
   fi
    
   aws iam delete-policy --policy-arn "${policy_arn}" 
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting permission policy.'     
   fi 
   
   return "${exit_code}" 
}

#===============================================================================
# Returns the policy ARN.
#
# Globals:
#  None
# Arguments:
# +policy_nm -- the policy name.
# Returns:      
#  the policy ARN, returns the value in the __RESULT global variable.  
#===============================================================================
function iam_get_permission_policy_arn()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r policy_nm="${1}"
   local policy_arn=''

   policy_arn="$(aws iam list-policies --query "Policies[? PolicyName=='${policy_nm}' ].Arn" \
       --output text)"
   
   if [[ -z "${policy_arn}" ]] 
   then
      echo 'Permission policy not found.'
   fi

   __RESULT="${policy_arn}"
   
   return "${exit_code}"
}

#===============================================================================
# Checks if a IAM managed policy exists.
#
# Globals:
#  None
# Arguments:
# +policy_nm -- the policy name.
# Returns:      
#  true or false value in the __RESULT global variable.  
#===============================================================================
function iam_check_permission_policy_exists()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   __RESULT='false'
   local exit_code=0
   local -r policy_nm="${1}"
   local policy_arn=''

   iam_get_permission_policy_arn "${policy_nm}"
   
   exit_code=$?
      
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving permission policy.' 
      return "${exit_code}"
   fi 
   
   policy_arn="${__RESULT}"
    
   if [[ -n "${policy_arn}" ]]
   then
      __RESULT='true'
   else
      __RESULT='false'
   fi

   return 0
}

#===============================================================================
# Attaches the specified managed permissions policy to the specified IAM role.
#
# Globals:
#  None
# Arguments:
# +role_nm   -- the role name.
# +policy_nm -- the policy name.
# Returns:      
#  none.  
#===============================================================================
function iam_attach_permission_policy_to_role()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r role_nm="${1}"
   local -r policy_nm="${2}"
   local policy_exists='false'

   iam_check_permission_policy_exists "${policy_nm}"
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving permission policy.' 
      return "${exit_code}"
   fi
   
   policy_exists="${__RESULT}"
   
   if [[ 'false' == "${policy_exists}" ]]
   then
      echo 'ERROR: permission policy not found.' 
      return 1
   fi
    
   iam_get_permission_policy_arn "${policy_nm}"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving permission policy ARN.' 
      return "${exit_code}"
   fi
   
   policy_arn="${__RESULT}"
   
   aws iam attach-role-policy --role-name "${role_nm}" --policy-arn "${policy_arn}" 
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: attaching permission policy to role.' 
   fi 

   return "${exit_code}" 
}

#===============================================================================
# Checks if the specified IAM role has a permission policy attached.
#
# Globals:
#  None
# Arguments:
# +role_nm   -- the role name.
# +policy_nm -- the policy name.
# Returns:      
#  true or false value in the __RESULT global variable.  
#===============================================================================
function iam_check_role_has_permission_policy_attached()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT='false'
   local exit_code=0
   local -r role_nm="${1}"
   local -r policy_nm="${2}"
   local role_exists='false'
   local policy_exists='false'
   local policy_arn=''
   
   iam_check_role_exists "${role_nm}"
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving role.' 
      return "${exit_code}"
   fi
   
   role_exists="${__RESULT}"
   
   if [[ 'false' == "${role_exists}" ]]
   then
      echo 'ERROR: role not found.' 
      return 1
   fi
   
   iam_check_permission_policy_exists "${policy_nm}"
   
   exit_code=$?

   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving permission policy.' 
      return "${exit_code}"
   fi
   
   policy_exists="${__RESULT}"
   
   if [[ 'false' == "${policy_exists}" ]]
   then
      echo 'ERROR: permission policy not found.' 
      return 1
   fi

   policy_arn="$(aws iam list-attached-role-policies --role-name "${role_nm}" \
       --query "AttachedPolicies[? PolicyName=='${policy_nm}'].PolicyArn" --output text)"
   
   if [[ -n "${policy_arn}" ]]
   then
      __RESULT='true'
   else
      __RESULT='false' 
   fi
       
   return "${exit_code}" 
}

#===============================================================================
# Removes the specified permissions policy from the specified IAM role.
#
# Globals:
#  None
# Arguments:
# +role_nm   -- the role name.
# +policy_nm -- the policy name.
# Returns:      
#  none.  
#=================$==============================================================
function iam_detach_permission_policy_from_role()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r role_nm="${1}"
   local -r policy_nm="${2}"
   local policy_arn=''
   local role_exists='false'
   local policy_exists='false'
   
   iam_check_role_exists "${role_nm}"
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving role.' 
      return "${exit_code}"
   fi
   
   role_exists="${__RESULT}"
   
   if [[ 'false' == "${role_exists}" ]]
   then
      echo 'ERROR: role not found.' 
      return 1
   fi
   
   iam_check_permission_policy_exists "${policy_nm}"
   
   exit_code=$?

   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving permission policy.' 
      return "${exit_code}"
   fi
   
   policy_exists="${__RESULT}"
   
   if [[ 'false' == "${policy_exists}" ]]
   then
      echo 'ERROR: permission policy not found.' 
      return 1
   fi
   
   iam_get_permission_policy_arn "${policy_nm}"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving permission policy ARN.' 
      return "${exit_code}"
   fi
   
   policy_arn="${__RESULT}"

   aws iam detach-role-policy --role-name "${role_nm}" --policy-arn "${policy_arn}" 
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: detaching permission policy from role.' 
   fi

   return "${exit_code}" 
}

#===============================================================================
# Builds the trust policy that allows EC2 instances to assume a role. 
# Trust policies define which entities can assume the role. 
# You can associate only one trust policy with a role.
#
# Globals:
#  None
# Arguments:
#  None
# Returns:      
#  The policy JSON document in the __RESULT global variable.  
#===============================================================================
function iam_build_assume_role_trust_policy_document_for_ec2_entities()
{
   __RESULT=''
   local policy_document=''

   policy_document=$(cat <<-EOF
	{
		"Version": "2012-10-17",
		"Statement": {
			"Effect": "Allow",
			"Principal": {"Service": "ec2.amazonaws.com"},
			"Action": "sts:AssumeRole"
		}
	}       
	EOF
   )
    
   __RESULT="${policy_document}"
   
   return 0
}

#===============================================================================
# Creates a new role for your AWS account.
#
# Globals:
#  None
# Arguments:
# +role_nm              -- the role name.
# +role_desc            -- the role description.
# +role_policy_document -- the trust policy that is associated with this role. 
# +decription           -- the role description.
# Returns:      
#  none.  
#===============================================================================
function iam_create_role()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r role_nm="${1}"
   local -r role_desc="${2}"
   local -r role_policy_document="${3}"

   aws iam create-role --role-name "${role_nm}" --description "${role_desc}" \
       --assume-role-policy-document "${role_policy_document}" \
       
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: creating role.' 
   fi

   return "${exit_code}" 
}

#===============================================================================
# Deletes the specified role, detaches instance profiles and permission policies
# from it.
#
# Globals:
#  None
# Arguments:
# +role_nm -- the role name.
# Returns:      
#  none.  
#===============================================================================
function iam_delete_role()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   __RESULT=''
   local exit_code=0
   local -r role_nm="${1}"
   local role_exists='false'
   
   iam_check_role_exists "${role_nm}"
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving the role.' 
      return "${exit_code}"
   fi
   
   role_exists="${__RESULT}"
   
   if [[ 'false' == "${role_exists}" ]]
   then
      echo 'ERROR: role not found.' 
      return 1
   fi
   
   # List the instance profiles for the role.
   instance_profiles="$(aws iam list-instance-profiles-for-role --role-name "${role_nm}" \
       --query "InstanceProfiles[].InstanceProfileName" --output text)"
   
   # List the permission policies attached to the role.
   policies="$(aws iam list-attached-role-policies --role-name "${role_nm}" --query "AttachedPolicies[].PolicyName" \
       --output text)" 
        
   # Detach the role from the instance profiles.
   for profile_nm in ${instance_profiles}
   do
      iam_remove_role_from_instance_profile "${profile_nm}" "${role_nm}" 
      exit_code=$?
      
      if [[ 0 -ne "${exit_code}" ]]
      then
         echo 'ERROR: removing role from instance profile.'
         return "${exit_code}"
      else 
         echo 'Role removed from instance profile.'
      fi      
   done
      
   # Detach the policies from role.
   for policy_nm in ${policies}
   do
      iam_detach_permission_policy_from_role "${role_nm}" "${policy_nm}" 
      exit_code=$?
      
      if [[ 0 -ne "${exit_code}" ]]
      then
         echo 'ERROR: detaching permission policy from role.'
         return "${exit_code}"
      else 
         echo 'Permission policy removed from role.'
      fi      
   done 
    
   aws iam delete-role --role-name "${role_nm}" 
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting role.'
   fi  
   
   return "${exit_code}" 
}

#===============================================================================
# Checks if a IAM role exists.
#
# Globals:
#  None
# Arguments:
# +role_nm -- the role name.
# Returns:      
#  true or false value in the __RESULT global variable.  
#===============================================================================
function iam_check_role_exists()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   __RESULT='false'
   local exit_code=0
   local -r role_nm="${1}"
   local role_id=''

   iam_get_role_id "${role_nm}"
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving role.'
      return "${exit_code}"
   fi
   
   role_id="${__RESULT}"
   
   if [[ -n "${role_id}" ]]
   then
      __RESULT='true'
   else
      __RESULT='false'
   fi

   return 0
}

#===============================================================================
# Returns a IAM role's ARN.
#
# Globals:
#  None
# Arguments:
# +role_nm -- the role name.
# Returns:      
#  the role's ARN in the __RESULT global variable.  
#===============================================================================
function iam_get_role_arn()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   __RESULT=''
   local exit_code=0
   local -r role_nm="${1}"
   local role_arn=''

   role_arn="$(aws iam list-roles --query "Roles[? RoleName=='${role_nm}'].Arn" --output text)"
   
   if [[ -z "${role_arn}" ]]
   then
      echo 'Role not found.'
   fi
   
   __RESULT="${role_arn}" 
       
   return "${exit_code}" 
}

#===============================================================================
# Returns a role's ID, or blanc if the role is not found.
#
# Globals:
#  None
# Arguments:
# +role_nm   -- the role name.
# Returns:      
#  the role ID in the __RESULT global variable.  
#===============================================================================
function iam_get_role_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r role_nm="${1}"
   local role_id=''

   role_id="$(aws iam list-roles \
       --query "Roles[? RoleName=='${role_nm}'].RoleId" --output text)"
          
   __RESULT="${role_id}" 
       
   return "${exit_code}" 
}

#===============================================================================
# Creates an instance profile. Amazon EC2 uses an instance profile as a 
# container for an IAM role. An instance profile can contain only one IAM role. 
#
# Globals:
#  None
# Arguments:
# +profile_nm -- the profile name.
# Returns:      
#  none.  
#===============================================================================
function iam_create_instance_profile()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r profile_nm="${1}"

   aws iam create-instance-profile --instance-profile-name "${profile_nm}"
       
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: creating instance profile.'
   fi

   return "${exit_code}" 
}

#===============================================================================
# Deletes the specified instance profile. If the instance profile has a role 
# associated, the role is detached.
#
# Globals:
#  None
# Arguments:
# +profile_nm -- the profile name.
# Returns:      
#  none.  
#===============================================================================
function iam_ec2_delete_instance_profile()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   __RESULT=''
   local exit_code=0
   local -r profile_nm="${1}"
   local role_nm=''
   
   # Only one role can be attached to an instance profile.
   role_nm="$(aws iam list-instance-profiles \
       --query "InstanceProfiles[? InstanceProfileName=='${profile_nm}' ].Roles[].RoleName" --output text)"

   if [[ -n "${role_nm}" ]]
   then
      # Detach the role from the instance profile.
      iam_remove_role_from_instance_profile "${profile_nm}" "${role_nm}" 
      
      echo 'Role detached from the instance profile.'
   else
      echo 'No role attached to the instance profile.'
   fi
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: removing role from instance profile.'
      return "${exit_code}"
   fi

   aws iam delete-instance-profile --instance-profile-name "${profile_nm}" 
   exit_code=$?

   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting instance profile.'
   fi

   return "${exit_code}" 
}

#===============================================================================
# Checks if a IAM instance profile exists.
#
# Globals:
#  None
# Arguments:
# +profile_nm -- the instance profile name.
# Returns:      
#  true or false value in the __RESULT global variable.  
#===============================================================================
function iam_check_instance_profile_exists()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT='false'
   local exit_code=0
   local -r profile_nm="${1}"
   local profile_id=''

   iam_get_instance_profile_id "${profile_nm}"
   exit_code=$? 
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving instance profile.'
      return "${exit_code}"
   fi
   
   profile_id="${__RESULT}"

   if [[ -n "${profile_id}" ]]
   then
      __RESULT='true'
   else
      __RESULT='false'
   fi

   return 0
}

#===============================================================================
# Returns an instance profile's ID.
#
# Globals:
#  None
# Arguments:
# +profile_nm -- the instance profile name.
# Returns:      
#  the instance profile ID in the __RESULT global variable. 
#===============================================================================
function iam_get_instance_profile_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r profile_nm="${1}"
   local profile_id=''
   
   profile_id="$(aws iam list-instance-profiles \
      --query "InstanceProfiles[?InstanceProfileName=='${profile_nm}'].InstanceProfileId" \
      --output text)"
  
   __RESULT="${profile_id}"

   return "${exit_code}"
}

#===============================================================================
# Checks if the specified instance profile has a role associated.
#
# Globals:
#  None
# Arguments:
# +profile_nm -- the profile name.
# +role_nm    -- the role name.
# Returns:      
#  true or false value in the __RESULT global variable.  
#===============================================================================
function iam_check_instance_profile_has_role_associated()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi    
    
   __RESULT='false'
   local exit_code=0
   local -r profile_nm="${1}"
   local -r role_nm="${2}"
   local role_exists=''
   local profile_exists=''
   local role_found=''
   
   iam_check_role_exists "${role_nm}"
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving the role.' 
      return "${exit_code}"
   fi
   
   role_exists="${__RESULT}"

   if [[ 'false' == "${role_exists}" ]]
   then
      echo 'ERROR: role not found.' 
      return 1
   fi
   
   iam_check_instance_profile_exists "${profile_nm}"
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving the instance profile.' 
      return "${exit_code}"
   fi
   
   profile_exists="${__RESULT}"
  
   if [[ 'false' == "${profile_exists}" ]]
   then
      echo 'ERROR: instance profile not found.' 
      return 1
   fi
    
   # One role per instance profile. 
   role_found="$(aws iam list-instance-profiles \
      --query "InstanceProfiles[? InstanceProfileName=='${profile_nm}' ].Roles[0].RoleName" \
      --output text)"

   if [[ "${role_nm}" == "${role_found}" ]]
   then
      __RESULT='true'
   else
      __RESULT='false'
   fi
   
   return "${exit_code}"
}

#===============================================================================
# Associates a role to an instance profile. 
#Amazon EC2 uses an instance profile as a  container for an IAM role.
#
# Globals:
#  None
# Arguments:
# +profile_nm -- the profile name.
# +role_nm    -- the role name.
# Returns:      
#  none.  
#===============================================================================
function iam_associate_role_to_instance_profile()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r profile_nm="${1}"
   local -r role_nm="${2}"
   
   aws iam add-role-to-instance-profile --instance-profile-name "${profile_nm}" \
      --role-name "${role_nm}" 
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: associating role to instance profile.'
   fi

   return "${exit_code}" 
}

#===============================================================================
# Removes the specified IAM role from the specified EC2 instance profile.
#
# Globals:
#  None
# Arguments:
# +profile_nm -- the profile name.
# +role_nm    -- the role name.
# Returns:      
#  none.  
#===============================================================================
function iam_remove_role_from_instance_profile()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r profile_nm="${1}"
   local -r role_nm="${2}"
   
   aws iam remove-role-from-instance-profile --instance-profile-name "${profile_nm}" \
      --role-name "${role_nm}" 

   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: removing role from instance profile.'
   fi

   return "${exit_code}" 
}

