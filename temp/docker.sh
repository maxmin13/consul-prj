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

STEP() { echo ; echo ; echo "==\\" ; echo "===>" "$@" ; echo "==/" ; echo ; }

LOGIN_USER='awsadmin'
SCRIPTS_DIR='/home/awsadmin/script'

source "${SCRIPTS_DIR}"/dockerlib.sh

# kernel version 3.10 or greater is needed.
uname -r

yum update -y

if ! docker version > /dev/null 2>&1 
then
   amazon-linux-extras install -y docker 
   systemctl start docker
   systemctl enable docker
fi 

docker_run_helloworld_container 'test'
docker_delete_container 'test'
docker_delete_img 'hello-world' 'latest'

echo 'Installed networks:'

docker network ls

echo
