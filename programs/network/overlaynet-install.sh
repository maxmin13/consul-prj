#!/bin/bash

# shellcheck disable=SC1091

########################################################################################################################
#
# Creates a cluster/swarm of Docker Engines with the AWS Admin instance as manager node, the other  
# instances join the cluster as workers. Creates an Docker overlay network on top of the nodes in the swarm. 
#
########################################################################################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# shellcheck disable=SC2034
LIBRARY_DIR='SEDlibrary_dirSED'	
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

echo "Docker swarm node mode ${node_mode}"

docker_swarm_status
swarm_status="${__RESULT}"

####
echo "Installing Docker overlay network ..."
####

if [[ 'manager' == "${node_mode}" ]]
then
   if [[ 'inactive' == "${swarm_status}" ]]
   then
      echo 'Initializing Docker swarm ...'
    
      get_datacenter_application_advertise_interface "${INSTANCE_KEY}" "${SWARM_KEY}" 'Ip'
      advertise_addr="${__RESULT}"
    
      docker_swarm_init "${advertise_addr}"
    
      echo 'Docker swarm initialized.'
    
      docker_swarm_get_worker_token
      swarm_token="${__RESULT}"
      get_datacenter_application "${INSTANCE_KEY}" "${SWARM_KEY}" 'JoinTokenName'
      swarm_token_nm="${__RESULT}"
      
      consul_put_key "${swarm_token_nm}" "${swarm_token}"
      
      echo 'Docker swarm join key stored in Consul vault.'    
   else
      echo 'WARN: Docker swarm already initialized.'
   fi
else
   echo 'Joining the instance to the Docker swarm ...'
   
   get_datacenter_application "${INSTANCE_KEY}" "${SWARM_KEY}" 'JoinTokenName'
   swarm_token_nm="${__RESULT}"
   consul_get_key "${swarm_token_nm}" 
   swarm_token="${__RESULT}"   
   
   get_datacenter_application_advertise_interface "${INSTANCE_KEY}" "${SWARM_KEY}" 'Ip'
   advertise_addr="${__RESULT}"
   get_datacenter_application_port "${INSTANCE_KEY}" "${SWARM_KEY}" 'ClusterPort'
   cluster_port="${__RESULT}"

   if [[ -n "${swarm_token}" ]]
   then
      docker_swarm_join "${swarm_token}" "${advertise_addr}" "${cluster_port}"
   
      echo 'Instance successfully joined the Docker swarm.'   
   else
      echo 'ERROR: Docker swarm token not found.'
      exit 1 
   fi
fi

if [[ 'manager' == "${node_mode}" ]]
then
   get_datacenter_network "${OVERLAYNET_KEY}" 'Name' 
   overlaynet_nm="${__RESULT}"
   get_datacenter_network "${OVERLAYNET_KEY}" 'Cidr' 
   overlaynet_cidr="${__RESULT}"

   docker_check_network_interface_exists "${overlaynet_nm}"
   overlaynet_exists="${__RESULT}"
   
   if [[ 'false' == "${overlaynet_exists}" ]]
   then
      echo 'Creating Docker overlay network'
   
      docker_network_create "${overlaynet_nm}" "${overlaynet_cidr}" 'overlay'
   
      echo 'Docker overlay network sucessfully installed.'
   else
      echo 'WARN: Docker overlay network already created.'
   fi
fi

# A worker host machine will recognize this network only when it hosts a container that connects into this overlay network.
# In a manager host machine the network is always visible.

docker_networks_display

echo


