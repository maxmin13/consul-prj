#!/usr/bin/bash 
 
# shellcheck disable=SC2034 

TMP_DIR="${PROJECT_DIR}"/temp
ACCESS_DIR="${PROJECT_DIR}"/access
PROVISION_DIR="${PROJECT_DIR}"/programs
SERVICES_DIR="${PROVISION_DIR}"/docker-services
LOGS_DIR="${PROJECT_DIR}"/logs/$(date +%Y%m%d)
