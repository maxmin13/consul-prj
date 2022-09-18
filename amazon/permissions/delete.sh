#!/bin/bash

########################################################
# Deletes the permissions policies associated to a role.
########################################################
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#
STEP 'Permissions'
#

check_permission_policy_exists  "${SECRETSMANAGER_POLICY_NM}" >> "${LOGS_DIR}"/permissions.log
secretsmanager_persmission_policy_exists="${__RESULT}"

if [[ 'false' == "${secretsmanager_persmission_policy_exists}" ]]
then
   echo '* WARN: SecretsManager permission policy not found.'
else
   get_permission_policy_arn "${SECRETSMANAGER_POLICY_NM}" >> "${LOGS_DIR}"/permissions.log
   secretsmanager_persmission_policy_arn="${__RESULT}"

   echo "* SecretsManager permission policy ARN: ${secretsmanager_persmission_policy_arn}"
fi

#
# SecretsManager permission policy
#

if [[ 'true' == "${secretsmanager_persmission_policy_exists}" ]]
then
   echo 'Deleting SecretsManager permission policy ...'
   
   delete_permission_policy "${SECRETSMANAGER_POLICY_NM}" >> "${LOGS_DIR}"/permissions.log
   
   echo 'SecretsManager permission policy deleted.'
fi

echo
