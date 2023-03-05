#!/usr/bin/bash 
 
# shellcheck disable=SC2034 

LIBRARY_DIR="${PROJECT_DIR}"/amazon/lib
CONSTANTS_DIR="${PROJECT_DIR}"/amazon/constants
TMP_DIR="${PROJECT_DIR}"/temp
ACCESS_DIR="${PROJECT_DIR}"/access
PROVISION_DIR="${PROJECT_DIR}"/applications
SERVICES_DIR="${PROVISION_DIR}"/docker-services
LOGS_DIR="${PROJECT_DIR}"/logs/$(date +%Y%m%d)
