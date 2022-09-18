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

check_permission_policy_exists  "${SECRETSMANAGER_POLICY_NM}" >> "${LOGS_DIR}"/permissions.log
secretsmanager_persmission_policy_exists="${__RESULT}"

if [[ 'false' == "${secretsmanager_persmission_policy_exists}" ]]
then
   # Create permission policy that allows entities to create, list, retrieve a secret from SecretsManager.
   build_secretsmanager_permission_policy_document 
   secretsmanager_permission_policy_document="${__RESULT}"

   create_permission_policy "${SECRETSMANAGER_POLICY_NM}" "${secretsmanager_permission_policy_document}" >> "${LOGS_DIR}"/permissions.log
   
   echo 'SecretsManager permission policy created.'
else
   echo 'WARN: SecretsManager permission policy already created.'
fi

