#!/bin/bash

########################################################################
#
# Installs a Docker engine.
#
# see:
#
#   systemctl show --property=FragmentPath docker
#   
# To customize the Docker daemon options using override files:
#
#   mkdir -p /etc/systemd/system/docker.service.d
#   touch /etc/systemd/system/docker.service.d/http-proxy.conf
#
#  [Service]
#  Environment="HTTP_PROXY=http://proxy.example.com:80/" "NO_PROXY=localhost,127.0.0.1,docker-registry.somecorporation.com"
#
#  sudo systemctl daemon-reload
#  systemctl show 
#  systemctl restart docker
#
########################################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

LIBRARY_DIR='SEDlibrary_dirSED'
CONSTANTS_DIR='SEDconstants_dirSED'

# shellcheck disable=SC1091
source "${LIBRARY_DIR}"/dockerlib.sh

STEP() { echo ; echo ; echo "==\\" ; echo "===>" "$@" ; echo "==/" ; echo ; }

# kernel version 3.10 or greater is needed.
uname -r

yum update -y 

if ! docker version
then
   amazon-linux-extras install -y docker
   systemctl start docker  
   systemctl enable docker 
   
   echo 'Docker started.'
fi 

docker_run_helloworld_container 'test'
docker_delete_container 'test'
docker_delete_img 'hello-world' 'latest'

echo 'Installed networks:'

docker network ls

echo
