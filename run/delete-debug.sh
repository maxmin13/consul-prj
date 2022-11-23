#!/bin/bash

# shellcheck disable=SC1091,SC2155

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace
 
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../consul-prj && pwd)"

source "${PROJECT_DIR}"/amazon/constants/project_dirs.sh
source "${CONSTANTS_DIR}"/app_consts.sh
source "${LIBRARY_DIR}"/datacenter_consts_utils.sh
source "${LIBRARY_DIR}"/service_consts_utils.sh
source "${LIBRARY_DIR}"/ssh_utils.sh
source "${LIBRARY_DIR}"/general_utils.sh
source "${LIBRARY_DIR}"/ec2_datacenter.sh
source "${LIBRARY_DIR}"/ecr_registry.sh
source "${LIBRARY_DIR}"/network.sh
source "${LIBRARY_DIR}"/dockerlib.sh
source "${LIBRARY_DIR}"/iam_auth.sh
source "${LIBRARY_DIR}"/secretsmanager_auth.sh

rm -rf "${TMP_DIR:?}"/*   
mkdir -p "${LOGS_DIR}"


. "${PROJECT_DIR}"/amazon/box/permissions/delete.sh 'sinatra-instance'
. "${PROJECT_DIR}"/amazon/box/delete.sh 'sinatra-instance' 'mm-network'


. "${PROJECT_DIR}"/amazon/box/permissions/delete.sh 'redis-instance'
. "${PROJECT_DIR}"/amazon/box/delete.sh 'redis-instance' 'mm-network'


. "${PROJECT_DIR}"/amazon/box/permissions/delete.sh 'admin-instance'
. "${PROJECT_DIR}"/amazon/box/delete.sh 'admin-instance' 'mm-network'

rm -rf "${TMP_DIR:?}"/*    

echo
