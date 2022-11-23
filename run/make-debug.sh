#!/bin/bash

# shellcheck disable=SC1091

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

## Datacenter ##

. "${PROJECT_DIR}"/amazon/datacenter/make.sh 'mm-network'

## Permission policies ##

. "${PROJECT_DIR}"/amazon/permissions/make.sh  

## AWS custom images ##

. "${PROJECT_DIR}"/amazon/box/make.sh 'shared-instance' 'mm-network'   
. "${PROJECT_DIR}"/amazon/box/provision/security/make.sh 'shared-instance'
. "${PROJECT_DIR}"/amazon/box/provision/updates/make.sh 'shared-instance'            
. "${PROJECT_DIR}"/amazon/image/make.sh 'shared-instance'              

   # Jumpbox.
. "${PROJECT_DIR}"/amazon/box/make.sh 'admin-instance' 'mm-network'	
. "${PROJECT_DIR}"/amazon/box/permissions/make.sh 'admin-instance'

## Docker base images ##

. "${PROJECT_DIR}"/amazon/registry/make.sh 'admin-instance' 

## AWS EC2 instances ##

. "${PROJECT_DIR}"/amazon/box/make.sh 'redis-instance' 'mm-network'
. "${PROJECT_DIR}"/amazon/box/permissions/make.sh 'redis-instance'


. "${PROJECT_DIR}"/amazon/box/make.sh 'sinatra-instance' 'mm-network'
. "${PROJECT_DIR}"/amazon/box/permissions/make.sh 'sinatra-instance'

rm -rf "${TMP_DIR:?}"/*   
