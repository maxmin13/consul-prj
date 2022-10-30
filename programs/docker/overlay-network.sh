#!/bin/bash

# shellcheck disable=SC1091

########################################################################################################################
# 
########################################################################################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

remote_dir='SEDremote_dirSED'
NETWORK_NM='SEDnetwork__nmSED'
NETWORK_CIDR='SEDnetwork_cidrSED'
NETWORK_GATE='SEDnetwork__gateSED'

source "${remote_dir}"/general_utils.sh
source "${remote_dir}"/dockerlib.sh

yum update -y 

####
echo 'Creating network ...'
####

systemctl stop docker
#docker daemon -H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock --cluster-advertise enp0s3:2375 --cluster-store consul://54.217.38.98:8500
#dockerd       -H fd:// --cluster-store=consul://consul:8500 --cluster-advertise=eth0:2376

docker_network_exists "${NETWORK_NM}"
overlay_net_exists="${__RESULT}"

if [[ 'false' == "${overlay_net_exists}" ]]
then
   # Create an overlay network which can be used by swarm services or standalone containers to communicate with 
   # other standalone containers running on other Docker daemons
   docker_network_create "${NETWORK_NM}" 'overlay' "${NETWORK_CIDR}" "${NETWORK_GATE}"

   echo 'Docker overlay network created.'
else 
   echo 'WARN: Docker overlay network already created.'
fi

echo
