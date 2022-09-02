#!/usr/bin/bash 
 
# shellcheck disable=SC2034 

TMP_DIR="${PROJECT_DIR}"/temp
ACCESS_DIR="${PROJECT_DIR}"/access
PROVISION_DIR="${PROJECT_DIR}"/provision
SERVICES_DIR="${PROJECT_DIR}"/provision/services
INSTANCE_DIR="${PROJECT_DIR}"/amazon/ec2
LIBRARY_DIR="${PROJECT_DIR}"/amazon/lib
LOGS_DIR="${PROJECT_DIR}"/logs/$(date +%Y%m%d)
