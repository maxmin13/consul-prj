#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#
STEP 'AWS Permissions'
#

check_role_exists "${ADMIN_ROLE_NM}"
admin_role_exists="${__RESULT}"

if [[ 'false' == "${admin_role_exists}" ]]
then
   echo '* WARN: Admin role not found.'
else
   get_role_arn "${ADMIN_ROLE_NM}" > /dev/null
   admin_role_arn="${__RESULT}"

   echo "* Admin role ARN: ${admin_role_arn}"
fi

check_role_exists "${NGINX_ROLE_NM}"
nginx_role_exists="${__RESULT}"

if [[ 'false' == "${nginx_role_exists}" ]]
then
   echo '* WARN: Nginx role not found.'
else
   get_role_arn "${NGINX_ROLE_NM}" > /dev/null
   nginx_role_arn="${__RESULT}"

   echo "* Nginx role ARN: ${nginx_role_arn}"
fi

check_role_exists "${JENKINS_ROLE_NM}"
jenkins_role_exists="${__RESULT}"

if [[ 'false' == "${jenkins_role_exists}" ]]
then
   echo '* WARN: Jenkins role not found.'
else
   get_role_arn "${JENKINS_ROLE_NM}" > /dev/null
   jenkins_role_arn="${__RESULT}"

   echo "* Jenkins role ARN: ${jenkins_role_arn}"
fi

check_role_exists "${REDIS_ROLE_NM}"
redis_role_exists="${__RESULT}"

if [[ 'false' == "${redis_role_exists}" ]]
then
   echo '* WARN: Redis role not found.'
else
   get_role_arn "${REDIS_ROLE_NM}" > /dev/null
   redis_role_arn="${__RESULT}"

   echo "* Redis role ARN: ${redis_role_arn}"
fi

echo

#
# Admin role
#

echo 'Deleting Admin role ...'

if [[ 'true' == "${admin_role_exists}" ]]
then
   delete_role "${ADMIN_ROLE_NM}" > /dev/null
   
   echo 'Admin role deleted.'
else
   echo 'WARN: Admin role already deleted.'
fi 

#
# Nginx role
#
   
echo 'Deleting Nginx role ...'

if [[ 'true' == "${nginx_role_exists}" ]]
then
   delete_role "${NGINX_ROLE_NM}" > /dev/null
   
   echo 'Nginx role deleted.'
else
   echo 'WARN: Nginx role already deleted.'
fi 
         
#
# Jenkins role
#
   
echo 'Deleting Jenkins role ...'

if [[ 'true' == "${jenkins_role_exists}" ]]
then
   delete_role "${JENKINS_ROLE_NM}" > /dev/null
   
   echo 'Jenkins role deleted.'
else
   echo 'WARN: Jenkins role already deleted.'
fi 
         
#
# Redis role
#
   
echo 'Deleting Redis role ...'

if [[ 'true' == "${redis_role_exists}" ]]
then
   delete_role "${REDIS_ROLE_NM}" > /dev/null
   
   echo 'Redis role deleted.'
else
   echo 'WARN: Redis role already deleted.'
fi

echo
