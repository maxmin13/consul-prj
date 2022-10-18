#!/bin/bash

########################################################
# Deletes the permissions policies associated to a role.
########################################################
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

logfile_nm='permissions.log'

#
STEP 'Permissions'
#

iam_check_permission_policy_exists  "${SECRETSMANAGER_POLICY_NM}" >> "${LOGS_DIR}"/"${logfile_nm}"
sm_policy_exists="${__RESULT}"

if [[ 'false' == "${sm_policy_exists}" ]]
then
   echo '* WARN: secretsmanager permission policy not found.'
else
   iam_get_permission_policy_arn "${SECRETSMANAGER_POLICY_NM}" >> "${LOGS_DIR}"/"${logfile_nm}"
   policy_arn="${__RESULT}"

   echo "* permission policy ARN: ${policy_arn}"
fi

echo

#
# Permission policy
#

if [[ 'true' == "${sm_policy_exists}" ]]
then
   echo 'Deleting secretsmanager permission policy ...'
   
   iam_delete_permission_policy "${SECRETSMANAGER_POLICY_NM}" >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo 'Secretsmanager permission policy delete.'
fi

echo
