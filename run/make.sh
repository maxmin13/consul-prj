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
source "${LIBRARY_DIR}"/dockerlib.sh
source "${LIBRARY_DIR}"/auth.sh
source "${LIBRARY_DIR}"/secretsmanager.sh

mkdir -p "${LOGS_DIR}"

. "${PROJECT_DIR}"/amazon/box/provision/service/make.sh 'jenkins-ik' 'jenkins-sk'

exit
exit

## Datacenter ##

. "${PROJECT_DIR}"/amazon/datacenter/make.sh 

## Permission policies ##

. "${PROJECT_DIR}"/amazon/permissions/make.sh  

## AWS custom images ##

. "${PROJECT_DIR}"/amazon/box/make.sh 'shared-ik'   
. "${PROJECT_DIR}"/amazon/box/provision/security/make.sh 'shared-ik'
. "${PROJECT_DIR}"/amazon/box/provision/updates/make.sh 'shared-ik'            
. "${PROJECT_DIR}"/amazon/image/make.sh 'shared-ik'              

   # Jumpbox.
. "${PROJECT_DIR}"/amazon/box/make.sh 'admin-ik'	
. "${PROJECT_DIR}"/amazon/box/permissions/make.sh 'admin-ik'
. "${PROJECT_DIR}"/amazon/box/provision/consul/make.sh 'admin-ik' 

## Docker base images ##
. "${PROJECT_DIR}"/amazon/registry/make.sh 

## AWS EC2 instances ##

. "${PROJECT_DIR}"/amazon/box/make.sh 'nginx-ik'
. "${PROJECT_DIR}"/amazon/box/permissions/make.sh 'nginx-ik'
. "${PROJECT_DIR}"/amazon/box/provision/consul/make.sh 'nginx-ik'
. "${PROJECT_DIR}"/amazon/box/provision/service/make.sh 'nginx-ik' 'nginx-sk'
. "${PROJECT_DIR}"/amazon/box/provision/service/webapp/deploy/make.sh 'nginx-ik' 'nginx-sk' 

. "${PROJECT_DIR}"/amazon/box/make.sh 'redis-ik'
. "${PROJECT_DIR}"/amazon/box/permissions/make.sh 'redis'
. "${PROJECT_DIR}"/amazon/box/provision/consul/make.sh 'redis-ik' 
. "${PROJECT_DIR}"/amazon/box/provision/service/make.sh 'redis-ik' 'redis-sk'

. "${PROJECT_DIR}"/amazon/box/make.sh 'sinatra-ik'
. "${PROJECT_DIR}"/amazon/box/permissions/make.sh 'sinatra'
. "${PROJECT_DIR}"/amazon/box/provision/consul/make.sh 'sinatra-ik'
. "${PROJECT_DIR}"/amazon/box/provision/service/webapp/deploy/make.sh 'sinatra-ik' 'sinatra-sk' 
. "${PROJECT_DIR}"/amazon/box/provision/service/make.sh 'sinatra-ik' 'sinatra-sk'

. "${PROJECT_DIR}"/amazon/box/make.sh 'jenkins-ik'
. "${PROJECT_DIR}"/amazon/box/permissions/make.sh 'jenkins-ik'
. "${PROJECT_DIR}"/amazon/box/provision/consul/make.sh 'jenkins-ik'
. "${PROJECT_DIR}"/amazon/box/provision/service/make.sh 'jenkins-ik' 'jenkins-sk'





