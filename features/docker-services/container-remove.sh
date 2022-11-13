#!/bin/bash

# shellcheck disable=SC1091

############################################################
# Removes a Docker container.
############################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

LIBRARY_DIR='SEDlibrary_dirSED'	
# shellcheck disable=SC2034
CONSTANTS_DIR='SEDconstants_dirSED'
CONTAINER_NM='SEDcontainer_nmSED'

source "${LIBRARY_DIR}"/dockerlib.sh

####
echo 'Removing container ...'
####

docker_check_container_exists "${CONTAINER_NM}"
container_exists="${__RESULT}"

if [[ 'true' == "${container_exists}" ]]
then
  docker_stop_container "${CONTAINER_NM}" 
  docker_delete_container "${CONTAINER_NM}" 
  
  echo 'Container removed.'
fi

echo
