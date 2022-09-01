#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#
STEP 'Permissions'
#

check_permission_policy_exists  "${SECRETSMANAGER_POLICY_NM}" | logto permissions.log
secretsmanager_persmission_policy_exists="${__RESULT}"

if [[ 'false' == "${secretsmanager_persmission_policy_exists}" ]]
then
   echo '* WARN: SecretsManager permission policy not found.'
else
   get_permission_policy_arn "${SECRETSMANAGER_POLICY_NM}" | logto permissions.log
   secretsmanager_persmission_policy_arn="${__RESULT}"

   echo "* SecretsManager permission policy ARN: ${secretsmanager_persmission_policy_arn}"
fi

check_role_exists "${ADMIN_AWS_ROLE_NM}"
admin_aws_role_exists="${__RESULT}"

if [[ 'false' == "${admin_aws_role_exists}" ]]
then
   echo '* WARN: Admin role not found.'
else
   get_role_arn "${ADMIN_AWS_ROLE_NM}" | logto permissions.log
   admin_aws_role_arn="${__RESULT}"

   echo "* Admin role ARN: ${admin_aws_role_arn}"
fi

check_role_exists "${REDIS_AWS_ROLE_NM}"
redis_aws_role_exists="${__RESULT}"

if [[ 'false' == "${redis_aws_role_exists}" ]]
then
   echo '* WARN: Redis role not found.'
else
   get_role_arn "${REDIS_AWS_ROLE_NM}" | logto permissions.log
   redis_aws_role_arn="${__RESULT}"

   echo "* Redis role ARN: ${redis_aws_role_arn}"
fi

check_role_exists "${NGINX_AWS_ROLE_NM}"
nginx_aws_role_exists="${__RESULT}"

if [[ 'false' == "${nginx_aws_role_exists}" ]]
then
   echo '* WARN: Nginx role not found.'
else
   get_role_arn "${NGINX_AWS_ROLE_NM}" | logto permissions.log
   nginx_aws_role_arn="${__RESULT}"

   echo "* Nginx role ARN: ${nginx_aws_role_arn}"
fi

check_role_exists "${SINATRA_AWS_ROLE_NM}"
sinatra_aws_role_exists="${__RESULT}"

if [[ 'false' == "${sinatra_aws_role_exists}" ]]
then
   echo '* WARN: Sinatra role not found.'
else
   get_role_arn "${SINATRA_AWS_ROLE_NM}" | logto permissions.log
   sinatra_aws_role_arn="${__RESULT}"

   echo "* Sinatra role ARN: ${sinatra_aws_role_arn}"
fi

check_role_exists "${JENKINS_AWS_ROLE_NM}"
jenkins_aws_role_exists="${__RESULT}"

if [[ 'false' == "${jenkins_aws_role_exists}" ]]
then
   echo '* WARN: Jenkins role not found.'
else
   get_role_arn "${JENKINS_AWS_ROLE_NM}" | logto permissions.log
   jenkins_aws_role_arn="${__RESULT}"

   echo "* Jenkins role ARN: ${jenkins_aws_role_arn}"
fi

echo

#
# Admin role
#

if [[ 'true' == "${admin_aws_role_exists}" ]]
then
   echo 'Deleting Admin role ...'
   
   delete_role "${ADMIN_AWS_ROLE_NM}" | logto permissions.log
   
   echo 'Admin role deleted.'
fi

#
# Nginx role
#

if [[ 'true' == "${nginx_aws_role_exists}" ]]
then
   echo 'Deleting Nginx role ...'
   
   delete_role "${NGINX_AWS_ROLE_NM}" | logto permissions.log
   
   echo 'Nginx role deleted.'
fi
         
#
# Jenkins role
#

if [[ 'true' == "${jenkins_aws_role_exists}" ]]
then
   echo 'Deleting Jenkins role ...'
   
   delete_role "${JENKINS_AWS_ROLE_NM}" | logto permissions.log
   
   echo 'Jenkins role deleted.'
fi
         
#
# Redis role
#

if [[ 'true' == "${redis_aws_role_exists}" ]]
then
   echo 'Deleting Redis role ...'
   
   delete_role "${REDIS_AWS_ROLE_NM}" | logto permissions.log
   
   echo 'Redis role deleted.'
fi

#
# Sinatra role
#

if [[ 'true' == "${sinatra_aws_role_exists}" ]]
then
   echo 'Deleting Sinatra role ...'
   
   delete_role "${SINATRA_AWS_ROLE_NM}" | logto permissions.log
   
   echo 'Sinatra role deleted.'
fi

#
# SecretsManager permission policy
#

if [[ 'true' == "${secretsmanager_persmission_policy_exists}" ]]
then
   echo 'Deleting SecretsManager permission policy ...'
   
   delete_permission_policy "${SECRETSMANAGER_POLICY_NM}" | logto permissions.log
   
   echo 'SecretsManager permission policy deleted.'
fi

echo
