#!/bin/bash

# shellcheck disable=SC1091

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
source "${LIBRARY_DIR}"/network.sh
source "${LIBRARY_DIR}"/dockerlib.sh
source "${LIBRARY_DIR}"/auth.sh
source "${LIBRARY_DIR}"/secretsmanager.sh

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
. "${PROJECT_DIR}"/amazon/box/provision/consul/make.sh 'admin-instance' 
. "${PROJECT_DIR}"/amazon/box/provision/network/make.sh 'admin-instance' 

## Docker base images ##

. "${PROJECT_DIR}"/amazon/registry/make.sh 'admin-instance' 

## AWS EC2 instances ##

. "${PROJECT_DIR}"/amazon/box/make.sh 'redis-instance' 'mm-network'
. "${PROJECT_DIR}"/amazon/box/permissions/make.sh 'redis-instance'
. "${PROJECT_DIR}"/amazon/box/provision/consul/make.sh 'redis-instance' 
. "${PROJECT_DIR}"/amazon/box/provision/network/make.sh 'redis-instance' 
. "${PROJECT_DIR}"/amazon/box/provision/service/make.sh 'redis-instance' 'redis-service'

. "${PROJECT_DIR}"/amazon/box/make.sh 'sinatra-instance' 'mm-network'
. "${PROJECT_DIR}"/amazon/box/permissions/make.sh 'sinatra-instance'
. "${PROJECT_DIR}"/amazon/box/provision/consul/make.sh 'sinatra-instance'
. "${PROJECT_DIR}"/amazon/box/provision/network/make.sh 'sinatra-instance' 
. "${PROJECT_DIR}"/amazon/box/provision/service/webapp/deploy/make.sh 'sinatra-instance' 'sinatra-service' 
. "${PROJECT_DIR}"/amazon/box/provision/service/make.sh 'sinatra-instance' 'sinatra-service'

. "${PROJECT_DIR}"/amazon/box/make.sh 'nginx-instance' 'mm-network'
. "${PROJECT_DIR}"/amazon/box/permissions/make.sh 'nginx-instance'
. "${PROJECT_DIR}"/amazon/box/provision/consul/make.sh 'nginx-instance'
. "${PROJECT_DIR}"/amazon/box/provision/service/make.sh 'nginx-instance' 'nginx-service'
. "${PROJECT_DIR}"/amazon/box/provision/service/webapp/deploy/make.sh 'nginx-instance' 'nginx-service'

. "${PROJECT_DIR}"/amazon/box/make.sh 'jenkins-instance' 'mm-network'
. "${PROJECT_DIR}"/amazon/box/permissions/make.sh 'jenkins-instance'
. "${PROJECT_DIR}"/amazon/box/provision/consul/make.sh 'jenkins-instance'
. "${PROJECT_DIR}"/amazon/box/provision/service/make.sh 'jenkins-instance' 'jenkins-service'


