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

check_permission_policy_exists  "${SECRETSMANAGER_POLICY_NM}" >> "${LOGS_DIR}"/"${logfile_nm}"
policy_exists="${__RESULT}"

if [[ 'false' == "${policy_exists}" ]]
then
   echo "* WARN: ${SECRETSMANAGER_POLICY_NM} permission policy not found."
else
   get_permission_policy_arn "${SECRETSMANAGER_POLICY_NM}" >> "${LOGS_DIR}"/"${logfile_nm}"
   policy_arn="${__RESULT}"

   echo "* permission policy ARN: ${policy_arn}"
fi

echo

#
# Permission policy
#

if [[ 'true' == "${policy_exists}" ]]
then
   echo "Deleting ${SECRETSMANAGER_POLICY_NM} permission policy ..."
   
   delete_permission_policy "${SECRETSMANAGER_POLICY_NM}" >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "${SECRETSMANAGER_POLICY_NM} permission policy deleted."
fi

echo
