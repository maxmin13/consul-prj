#!/bin/bash

# shellcheck disable=SC1091

########################################################################################################################
# Consul is a datacenter runtime that provides service discovery, configuration, and orchestration.
# By default, Consul allows connections to the following ports only from the loopback interface (127.0.0.1). 
#  8500: handles HTTP API requests from clients
#  8400: handles requests from CLI
#  8600: answers DNS queries
#
#   dig @0.0.0.0 -p 8600 node1.node.consul
#   curl localhost:8500/v1/catalog/nodes
#
########################################################################################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR='SEDscripts_dirSED'
CONSUL_DOCKER_CONTAINER_NM='SEDconsul_docker_container_nmSED'
CONSUL_DOCKER_REGISTRY_IMG_NM='SEDconsul_docker_registry_img_nmSED'
CONSUL_DOCKER_REGISTRY_IMG_TAG='SEDconsul_docker_registry_img_tagSED'
CONSUL_DOCKER_NETWORK_DRIVER_NM='SEDconsul_docker_network_driver_nmSED'
CONSUL_DOCKER_HOST_VOLUME_DIR_NM='SEDconsul_docker_host_volume_dir_nmSED'
CONSUL_DOCKER_CONTAINER_STATE_DIR_NM='SEDconsul_docker_container_state_dir_nmSED'
CONSUL_SERVER_NM='SEDconsul_server_nmSED' 
CONSUL_NETWORK_INTERFACE_NM='consul0'
CONSUL_IP_BIND_ADDRESS='SEDconsul_ip_bind_addressSED'

source "${SCRIPTS_DIR}"/app_consts.sh
source "${SCRIPTS_DIR}"/general_utils.sh
source "${SCRIPTS_DIR}"/dockerlib.sh
source "${SCRIPTS_DIR}"/network.sh

yum update -y


####
echo 'Installing Consul ...'
####

docker_check_container_exists "${CONSUL_DOCKER_CONTAINER_NM}"
exists="${__RESULT}"

if [[ 'true' == "${exists}" ]]
then
  docker_stop_container "${CONSUL_DOCKER_CONTAINER_NM}" 
  docker_delete_container "${CONSUL_DOCKER_CONTAINER_NM}" 
  
  echo 'Consul container removed.'
fi

check_network_interface_exists "${CONSUL_NETWORK_INTERFACE_NM}"
exists="${__RESULT}"

if [[ 'false' == "${exists}" ]]
then
   create_network_interface "${CONSUL_NETWORK_INTERFACE_NM}" "${CONSUL_IP_BIND_ADDRESS}" 'dummy'

   echo 'Network interface created.'
else
   echo 'WARN: network interface already created.'
fi

echo 'Running Consul container ...'

# Run Consul in a Docker 'host' driver network.
docker_run_consul_server_container "${CONSUL_DOCKER_CONTAINER_NM}" \
                                   "${CONSUL_DOCKER_REGISTRY_IMG_NM}" \
                                   "${CONSUL_DOCKER_REGISTRY_IMG_TAG}" \
                                   "${CONSUL_DOCKER_NETWORK_DRIVER_NM}" \
                                   "${CONSUL_DOCKER_HOST_VOLUME_DIR_NM}" \
                                   "${CONSUL_DOCKER_CONTAINER_STATE_DIR_NM}" \
                                   "${CONSUL_SERVER_NM}" \
                                   "${CONSUL_IP_BIND_ADDRESS}"    
   
docker_exec 'consul' consul version -format=json

#docker_exec 'consul' echo "{'client_addr': '169.254.1.1','bind_addr': 'HOST_IP_ADDRESS'}" > /etc/consul.d/interfaces.json                              

#docker restart consul

echo 'Consul container running.'     



echo
##echo "http://${CONSUL_IP_ADDRESS}:${CONSUL_HTTP_PORT}/ui"
##echo "dig @${CONSUL_IP_ADDRESS} -p 8600 node1.node.consul"
echo
