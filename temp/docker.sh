#!/bin/bash

####################################
# Installs Docker server.
####################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

STEP() { echo ; echo ; echo "==\\" ; echo "===>" "$@" ; echo "==/" ; echo ; }

LOGIN_USER='awsadmin'

####
STEP "Docker"
####

# kernel version 3.10 or greater is needed.
uname -r

yum update -y

if ! docker version > /dev/null 2>&1 
then
   amazon-linux-extras install -y docker 
   systemctl start docker
   systemctl enable docker
fi 

docker run --name test -i -t hello-world
docker rm test
docker rmi hello-world

#if ! groups "${LOGIN_USER}" | grep docker
#then
#   usermod -aG docker "${LOGIN_USER}"
#   
#   echo "${LOGIN_USER} added to docker group."
#else
#   echo "${LOGIN_USER} already added to docker group."
#fi

echo
