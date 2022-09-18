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

## Docker base images ##

. "${PROJECT_DIR}"/amazon/registry/delete.sh  ##  TODO TODO check jenkins repo not deleted

## AWS EC2 instances ##

. "${PROJECT_DIR}"/amazon/box/permissions/delete.sh 'jenkins'
. "${PROJECT_DIR}"/amazon/box/delete.sh 'jenkins'

. "${PROJECT_DIR}"/amazon/box/permissions/delete.sh 'nginx'
. "${PROJECT_DIR}"/amazon/box/delete.sh 'nginx'

. "${PROJECT_DIR}"/amazon/box/permissions/delete.sh 'sinatra'
. "${PROJECT_DIR}"/amazon/box/delete.sh 'sinatra'

. "${PROJECT_DIR}"/amazon/box/provision/consul/delete.sh 'redis' 
. "${PROJECT_DIR}"/amazon/box/permissions/delete.sh 'redis'
. "${PROJECT_DIR}"/amazon/box/delete.sh 'redis'

   # Jumpbox.
. "${PROJECT_DIR}"/amazon/box/provision/consul/delete.sh 'admin'   ##  TODO TODO check key not deleted
. "${PROJECT_DIR}"/amazon/box/permissions/delete.sh 'admin'
. "${PROJECT_DIR}"/amazon/box/delete.sh 'admin'

## AWS custom images ##

. "${PROJECT_DIR}"/amazon/box/delete.sh 'shared'          
. "${PROJECT_DIR}"/amazon/image/delete.sh 'shared'           

## Permission policies ##

. "${PROJECT_DIR}"/amazon/permissions/delete.sh  

## Datacenter ##

. "${PROJECT_DIR}"/amazon/datacenter/delete.sh  

echo
