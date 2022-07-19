#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace


#################################################################################
# When you use a role, you don't have to distribute long-term credentials 
# (such as a user name and password or access keys) to an EC2 instance. 
# Instead, the role supplies temporary permissions that applications can use when 
# they make calls to other AWS resources.
#################################################################################

#
STEP 'AWS Permissions'
#

# Create an IAM role that has full access to the ECR service. 
# The role is entrusted to EC2 instances. 

# Create the trust relationship policy document that grants the EC2 instances the
# permission to assume the role.
build_assume_role_policy_document_for_ec2_entities 
trust_policy_document="${__RESULT}"

#
# Admin role
#

check_role_exists "${ADMIN_ROLE_NM}"
admin_role_exists="${__RESULT}"

if [[ 'false' == "${admin_role_exists}" ]]
then
   create_role "${ADMIN_ROLE_NM}" 'ECR full access role for the Admin instance.' "${trust_policy_document}" > /dev/null
   
   echo 'Admin role created.'
else
   echo 'WARN: Admin role already created.'
fi

check_role_has_permission_policy_attached "${ADMIN_ROLE_NM}" "${REGISTRY_POLICY_NM}"
admn_policy_attached="${__RESULT}"

if [[ 'false' == "${admn_policy_attached}" ]]
then
   attach_permission_policy_to_role "${ADMIN_ROLE_NM}" "${REGISTRY_POLICY_NM}"
   
   echo 'ECR permission policy attached to the Admin role.'
else
   echo 'WARN: ECR permission policy already attached to the Admin role.'
fi

echo

#
# Nginx role
#

check_role_exists "${NGINX_ROLE_NM}"
nginx_role_exists="${__RESULT}"

if [[ 'false' == "${nginx_role_exists}" ]]
then
   create_role "${NGINX_ROLE_NM}" 'ECR full access role for the Nginx instance.' "${trust_policy_document}" > /dev/null
   
   echo 'Nginx role created.'
else
   echo 'WARN: Nginx role already created.'
fi

check_role_has_permission_policy_attached "${NGINX_ROLE_NM}" "${REGISTRY_POLICY_NM}"
admn_policy_attached="${__RESULT}"

if [[ 'false' == "${admn_policy_attached}" ]]
then
   attach_permission_policy_to_role "${NGINX_ROLE_NM}" "${REGISTRY_POLICY_NM}"
   
   echo 'ECR permission policy attached to the Nginx role.'
else
   echo 'WARN: ECR permission policy already attached to the Nginx role.'
fi

echo

#
# Jenkins role
#

check_role_exists "${JENKINS_ROLE_NM}"
jenkins_role_exists="${__RESULT}"

if [[ 'false' == "${jenkins_role_exists}" ]]
then
   create_role "${JENKINS_ROLE_NM}" 'ECR full access role for the Jenkins instance.' "${trust_policy_document}" > /dev/null
   
   echo 'Jenkins role created.'
else
   echo 'WARN: Jenkins role already created.'
fi

check_role_has_permission_policy_attached "${JENKINS_ROLE_NM}" "${REGISTRY_POLICY_NM}"
admn_policy_attached="${__RESULT}"

if [[ 'false' == "${admn_policy_attached}" ]]
then
   attach_permission_policy_to_role "${JENKINS_ROLE_NM}" "${REGISTRY_POLICY_NM}"
   
   echo 'ECR permission policy attached to the Jenkins role.'
else
   echo 'WARN: ECR permission policy already attached to the Jenkins role.'
fi

echo

#
# Redis db role
#

check_role_exists "${REDIS_ROLE_NM}"
redis_role_exists="${__RESULT}"

if [[ 'false' == "${redis_role_exists}" ]]
then
   create_role "${REDIS_ROLE_NM}" 'ECR full access role for the Redis instance.' "${trust_policy_document}" > /dev/null
   
   echo 'Redis db role created.'
else
   echo 'WARN: Redis db role already created.'
fi

check_role_has_permission_policy_attached "${REDIS_ROLE_NM}" "${REGISTRY_POLICY_NM}"
admn_policy_attached="${__RESULT}"

if [[ 'false' == "${admn_policy_attached}" ]]
then
   attach_permission_policy_to_role "${REDIS_ROLE_NM}" "${REGISTRY_POLICY_NM}"
   
   echo 'ECR permission policy attached to the Redis db role.'
else
   echo 'WARN: ECR permission policy already attached to the Redis db role.'
fi

echo
echo 'AWS permissions configured.'

