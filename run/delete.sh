#!/bin/bash

# shellcheck disable=SC1091,SC2155

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace
 
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../consul-prj && pwd)"
LIBRARY_DIR="${PROJECT_DIR}"/amazon/lib

source "${LIBRARY_DIR}"/constants/project_dirs.sh
source "${LIBRARY_DIR}"/constants/app_consts.sh
source "${LIBRARY_DIR}"/datacenter_consts_utils.sh
source "${LIBRARY_DIR}"/service_consts_utils.sh
source "${LIBRARY_DIR}"/ssh_utils.sh
source "${LIBRARY_DIR}"/general_utils.sh
source "${LIBRARY_DIR}"/datacenter.sh
source "${LIBRARY_DIR}"/registry.sh
source "${LIBRARY_DIR}"/dockerlib.sh
source "${LIBRARY_DIR}"/auth.sh
source "${LIBRARY_DIR}"/secretsmanager.sh

mkdir -p "${LOGS_DIR}"

## Docker base images ##

. "${PROJECT_DIR}"/amazon/registry/delete.sh 'admin-instance'  

## AWS EC2 instances ##

. "${PROJECT_DIR}"/amazon/box/provision/consul/delete.sh 'jenkins-instance' 
. "${PROJECT_DIR}"/amazon/box/permissions/delete.sh 'jenkins-instance'
. "${PROJECT_DIR}"/amazon/box/delete.sh 'jenkins-instance' 'consul-network'

. "${PROJECT_DIR}"/amazon/box/provision/consul/delete.sh 'nginx-instance' 
. "${PROJECT_DIR}"/amazon/box/permissions/delete.sh 'nginx-instance'
. "${PROJECT_DIR}"/amazon/box/delete.sh 'nginx-instance' 'consul-network'

. "${PROJECT_DIR}"/amazon/box/provision/consul/delete.sh 'sinatra-instance' 
. "${PROJECT_DIR}"/amazon/box/permissions/delete.sh 'sinatra-instance'
. "${PROJECT_DIR}"/amazon/box/delete.sh 'sinatra-instance' 'consul-network'

. "${PROJECT_DIR}"/amazon/box/provision/consul/delete.sh 'redis-instance' 
. "${PROJECT_DIR}"/amazon/box/permissions/delete.sh 'redis-instance'
. "${PROJECT_DIR}"/amazon/box/delete.sh 'redis-instance' 'consul-network'

   # Jumpbox.
. "${PROJECT_DIR}"/amazon/box/provision/consul/delete.sh 'admin-instance'
. "${PROJECT_DIR}"/amazon/box/permissions/delete.sh 'admin-instance'
. "${PROJECT_DIR}"/amazon/box/delete.sh 'admin-instance' 'consul-network'

## AWS custom images ##

. "${PROJECT_DIR}"/amazon/box/delete.sh 'shared-instance' 'consul-network'      
. "${PROJECT_DIR}"/amazon/image/delete.sh 'shared-instance'           

## Permission policies ##

. "${PROJECT_DIR}"/amazon/permissions/delete.sh  

## Datacenter ##

. "${PROJECT_DIR}"/amazon/datacenter/delete.sh 'consul-network'     

echo
