#!/bin/bash

# shellcheck disable=SC1091,SC2155

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace
 
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../docker-prj && pwd)"

source "${PROJECT_DIR}"/amazon/lib/constants/app_consts.sh
source "${PROJECT_DIR}"/amazon/lib/constants/project_dirs.sh
source "${PROJECT_DIR}"/amazon/lib/constants/docker.sh
source "${PROJECT_DIR}"/amazon/lib/ssh_utils.sh
source "${PROJECT_DIR}"/amazon/lib/general_utils.sh
source "${PROJECT_DIR}"/amazon/lib/ec2.sh
source "${PROJECT_DIR}"/amazon/lib/ecr.sh
source "${PROJECT_DIR}"/amazon/lib/dockerlib.sh
source "${PROJECT_DIR}"/amazon/lib/iam.sh

echo

# Docker base images.
. "${PROJECT_DIR}"/amazon/ecr/delete.sh 

# AWS instances.
. "${PROJECT_DIR}"/amazon/ec2/jenkins/delete.sh
. "${PROJECT_DIR}"/amazon/ec2/nginx/delete.sh
. "${PROJECT_DIR}"/amazon/ec2/redisdb/delete.sh
. "${PROJECT_DIR}"/amazon/ec2/sinatra/delete.sh

# Jumpbox.
. "${PROJECT_DIR}"/amazon/ec2/admin/delete.sh

# AWS shared image.
. "${PROJECT_DIR}"/amazon/ec2/shared/delete.sh              
. "${PROJECT_DIR}"/amazon/image/shared/delete.sh             

# Users and policies
. "${PROJECT_DIR}"/amazon/permissions/delete.sh  

# Datacenter.
. "${PROJECT_DIR}"/amazon/datacenter/delete.sh  

echo
