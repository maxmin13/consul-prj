#!/bin/bash

# shellcheck disable=SC1091,SC2155

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace
 
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../consul-prj && pwd)"

source "${PROJECT_DIR}"/amazon/lib/constants/app_consts.sh
source "${PROJECT_DIR}"/amazon/lib/constants/project_dirs.sh
source "${PROJECT_DIR}"/amazon/lib/constants/docker.sh
source "${PROJECT_DIR}"/amazon/lib/ssh_utils.sh
source "${PROJECT_DIR}"/amazon/lib/general_utils.sh
source "${PROJECT_DIR}"/amazon/lib/ec2.sh
source "${PROJECT_DIR}"/amazon/lib/ecr.sh
source "${PROJECT_DIR}"/amazon/lib/dockerlib.sh
source "${PROJECT_DIR}"/amazon/lib/iam.sh
source "${PROJECT_DIR}"/amazon/lib/secretsmanager.sh

mkdir -p "${LOGS_DIR}"

# Datacenter.
. "${PROJECT_DIR}"/amazon/datacenter/make.sh  

# Users and policies
. "${PROJECT_DIR}"/amazon/permissions/make.sh  

# AWS shared image.
. "${PROJECT_DIR}"/amazon/ec2/shared/make.sh              
. "${PROJECT_DIR}"/amazon/image/shared/make.sh            
. "${PROJECT_DIR}"/amazon/ec2/shared/delete.sh  

# Linux jumpbox.
. "${PROJECT_DIR}"/amazon/ec2/admin/make.sh

. "${PROJECT_DIR}"/amazon/ec2/admin/consul/make.sh

# Docker base images.
. "${PROJECT_DIR}"/amazon/ecr/make.sh 

# AWS instances.
. "${PROJECT_DIR}"/amazon/ec2/redis/make.sh
. "${PROJECT_DIR}"/amazon/ec2/redis/consul/make.sh 
. "${PROJECT_DIR}"/amazon/ec2/sinatra/make.sh
. "${PROJECT_DIR}"/amazon/ec2/jenkins/make.sh
. "${PROJECT_DIR}"/amazon/ec2/nginx/make.sh


