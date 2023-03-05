#!/bin/bash

# shellcheck disable=SC1091

########################################################################################################################
#
# Removes overlay network, swarm, access token. 
#
########################################################################################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# shellcheck disable=SC2034
LIBRARY_DIR='SEDlibrary_dirSED'	
# shellcheck disable=SC2034
CONSTANTS_DIR='SEDconstants_dirSED'
INSTANCE_KEY='SEDinstance_keySED'
SWARM_KEY='SEDswarm_keySED'	
OVERLAYNET_KEY='SEDoverlaynet_keySED'							

source "${LIBRARY_DIR}"/general_utils.sh
source "${LIBRARY_DIR}"/datacenter_consts_utils.sh
source "${LIBRARY_DIR}"/dockerlib.sh
source "${LIBRARY_DIR}"/consul.sh

yum update -y 

get_datacenter_application "${INSTANCE_KEY}" "${SWARM_KEY}" 'NodeMode'
node_mode="${__RESULT}"

if [[ 'manager' == "${node_mode}" ]]
then
   get_datacenter_network "${OVERLAYNET_KEY}" 'Name' 
   overlaynet_nm="${__RESULT}"
   docker_check_network_interface_exists "${overlaynet_nm}"
   overlaynet_exists="${__RESULT}"
   
   if [[ 'true' == "${overlaynet_exists}" ]]
   then
      echo 'WARN: the overlay network is already created.'
      echo 'Before removing any running container should be stopped.'
      echo 'Removing ...'
   
      # If any container is running in the network, the following delete command will throw an error.
      docker_network_remove "${overlaynet_nm}" 
   
      echo 'Overlay network sucessfully removed.'
    else
      echo 'Overlay network not found.'
   fi
fi

echo "Node swarm mode ${node_mode}"

docker_swarm_status
swarm_status="${__RESULT}"

if [[ 'inactive' != "${swarm_status}" ]]
then
   echo 'WARN: the node is already part of a swarm, leaving ...'
 
   docker_swarm_leave
fi

if [[ 'manager' == "${node_mode}" ]]
then
   get_datacenter_application "${INSTANCE_KEY}" "${SWARM_KEY}" 'JoinTokenName'
   swarm_token_nm="${__RESULT}"
   consul_check_key_exists "${swarm_token_nm}" 
   token_exists="${__RESULT}"
   
   if [[ 'true' == "${token_exists}" ]]
   then
      echo 'WARN: found swarm token, deleting ...'
      
      consul_remove_key "${swarm_token_nm}"
      
      echo 'Swarm token deleted.'
   fi
fi

echo


