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

logfile_nm='permissions.log'

#
STEP 'Permissions'
#

iam_check_permission_policy_exists  "${SECRETSMANAGER_POLICY_NM}" >> "${LOGS_DIR}"/"${logfile_nm}"
sm_policy_exists="${__RESULT}"

if [[ 'false' == "${sm_policy_exists}" ]]
then
   # Create permission policy that allows entities to create, list, retrieve a secret from SecretsManager.
   iam_build_secretsmanager_permission_policy_document 
   policy_document="${__RESULT}"

   iam_create_permission_policy "${SECRETSMANAGER_POLICY_NM}" "${policy_document}" >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo 'Secretsmanager permission policy created.'
else
   echo 'WARN: secretsmanager permission policy already created.'
fi

