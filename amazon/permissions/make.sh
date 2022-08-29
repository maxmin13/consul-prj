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
STEP 'Permissions'
#

# Create the trust relationship policy document that grants the EC2 instances the
# permission to assume the role.
build_assume_role_trust_policy_document_for_ec2_entities 
trust_policy_document="${__RESULT}"

check_permission_policy_exists  "${SECRETSMANAGER_POLICY_NM}" > /dev/null
secretsmanager_persmission_policy_exists="${__RESULT}"

if [[ 'false' == "${secretsmanager_persmission_policy_exists}" ]]
then
   # Create permission policy that allows entities to create, list, retrieve a secret from SecretsManager.
   build_secretsmanager_permission_policy_document 
   secretsmanager_permission_policy_document="${__RESULT}"

   create_permission_policy "${SECRETSMANAGER_POLICY_NM}" "${secretsmanager_permission_policy_document}"
   
   echo 'SecretsManager permission policy created.'
else
   echo 'WARN: SecretsManager permission policy already created.'
fi

#
# Admin role
#

check_role_exists "${ADMIN_AWS_ROLE_NM}"
admin_aws_role_exists="${__RESULT}"

if [[ 'false' == "${admin_aws_role_exists}" ]]
then
   create_role "${ADMIN_AWS_ROLE_NM}" 'Admin instance role' "${trust_policy_document}" > /dev/null
   
   echo 'Admin role created.'
else
   echo 'WARN: Admin role already created.'
fi

#
# Redis role
#

check_role_exists "${REDIS_AWS_ROLE_NM}"
redis_aws_role_exists="${__RESULT}"

if [[ 'false' == "${redis_aws_role_exists}" ]]
then
   create_role "${REDIS_AWS_ROLE_NM}" 'Redis instance role' "${trust_policy_document}" > /dev/null
   
   echo 'Redis role created.'
else
   echo 'WARN: Redis role already created.'
fi

#
# Nginx role
#

check_role_exists "${NGINX_AWS_ROLE_NM}"
nginx_aws_role_exists="${__RESULT}"

if [[ 'false' == "${nginx_aws_role_exists}" ]]
then
   create_role "${NGINX_AWS_ROLE_NM}" 'Nginx instance role' "${trust_policy_document}" > /dev/null
   
   echo 'Nginx role created.'
else
   echo 'WARN: Nginx role already created.'
fi

#
# Jenkins role
#

check_role_exists "${JENKINS_AWS_ROLE_NM}"
jenkins_aws_role_exists="${__RESULT}"

if [[ 'false' == "${jenkins_aws_role_exists}" ]]
then
   create_role "${JENKINS_AWS_ROLE_NM}" 'Jenkins instance role.' "${trust_policy_document}" > /dev/null
   
   echo 'Jenkins role created.'
else
   echo 'WARN: Jenkins role already created.'
fi

#
# Sinatra role
#

check_role_exists "${SINATRA_AWS_ROLE_NM}"
sinatra_aws_role_exists="${__RESULT}"

if [[ 'false' == "${sinatra_aws_role_exists}" ]]
then
   create_role "${SINATRA_AWS_ROLE_NM}" 'Sinatra instance role' "${trust_policy_document}" > /dev/null
   
   echo 'Sinatra role created.'
else
   echo 'WARN: Sinatra role already created.'
fi

echo
echo 'Permissions configured.'

