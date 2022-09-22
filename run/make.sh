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
source "${LIBRARY_DIR}"/constants/docker.sh
source "${LIBRARY_DIR}"/ec2_consts_utils.sh
source "${LIBRARY_DIR}"/ssh_utils.sh
source "${LIBRARY_DIR}"/general_utils.sh
source "${LIBRARY_DIR}"/ec2.sh
source "${LIBRARY_DIR}"/ecr.sh
source "${LIBRARY_DIR}"/dockerlib.sh
source "${LIBRARY_DIR}"/iam.sh
source "${LIBRARY_DIR}"/secretsmanager.sh

mkdir -p "${LOGS_DIR}"

## Datacenter ##

. "${PROJECT_DIR}"/amazon/datacenter/make.sh  

## Permission policies ##

. "${PROJECT_DIR}"/amazon/permissions/make.sh  

## AWS custom images ##

. "${PROJECT_DIR}"/amazon/box/make.sh 'shared'   
. "${PROJECT_DIR}"/amazon/box/provision/security/make.sh 'shared'  
. "${PROJECT_DIR}"/amazon/box/provision/docker/make.sh 'shared'              
. "${PROJECT_DIR}"/amazon/image/make.sh 'shared'              

   # Jumpbox.
. "${PROJECT_DIR}"/amazon/box/make.sh 'admin'
. "${PROJECT_DIR}"/amazon/box/permissions/make.sh 'admin'
. "${PROJECT_DIR}"/amazon/box/provision/consul/make.sh 'admin' 

## Docker base images ##

. "${PROJECT_DIR}"/amazon/registry/make.sh 

## AWS EC2 instances ##

. "${PROJECT_DIR}"/amazon/box/make.sh 'redis'
. "${PROJECT_DIR}"/amazon/box/permissions/make.sh 'redis'
. "${PROJECT_DIR}"/amazon/box/provision/consul/make.sh 'redis' 
. "${PROJECT_DIR}"/amazon/box/provision/redis/make.sh 'redis'

### TODO create consul.sh and register redis container with Consul agent.

. "${PROJECT_DIR}"/amazon/box/make.sh 'sinatra'
. "${PROJECT_DIR}"/amazon/box/permissions/make.sh 'sinatra'
. "${PROJECT_DIR}"/amazon/box/provision/consul/make.sh 'sinatra'
. "${PROJECT_DIR}"/amazon/box/provision/sinatra/make.sh 'sinatra'

. "${PROJECT_DIR}"/amazon/box/make.sh 'jenkins'
. "${PROJECT_DIR}"/amazon/box/permissions/make.sh 'jenkins'
. "${PROJECT_DIR}"/amazon/box/provision/consul/make.sh 'jenkins'
. "${PROJECT_DIR}"/amazon/box/provision/jenkins/make.sh 'jenkins'

. "${PROJECT_DIR}"/amazon/box/make.sh 'nginx'
. "${PROJECT_DIR}"/amazon/box/permissions/make.sh 'nginx'
. "${PROJECT_DIR}"/amazon/box/provision/consul/make.sh 'nginx'
. "${PROJECT_DIR}"/amazon/box/provision/nginx/make.sh 'nginx'



