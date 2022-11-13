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

####
echo "Creating overlay network ..."
####

get_datacenter_application "${INSTANCE_KEY}" "${SWARM_KEY}" 'NodeMode'
node_mode="${__RESULT}"

if [[ 'manager' == "${node_mode}" ]]
then       
   echo 'Initializing swarm ...'
   
   get_datacenter_application_advertise_interface "${INSTANCE_KEY}" "${SWARM_KEY}" 'Ip'
   advertise_addr="${__RESULT}"   
   
   docker_swarm_init "${advertise_addr}"
    
   echo 'Swarm initialized.'
    
   docker_swarm_get_worker_token
   swarm_token="${__RESULT}"
   get_datacenter_application "${INSTANCE_KEY}" "${SWARM_KEY}" 'JoinTokenName'
   swarm_token_nm="${__RESULT}"
      
   consul_put_key "${swarm_token_nm}" "${swarm_token}"
     
   echo 'Swarm join key stored in the Consul vault.'    
else 
   echo 'Joining the node to the swarm ...'
   
   get_datacenter_application "${INSTANCE_KEY}" "${SWARM_KEY}" 'JoinTokenName'
   swarm_token_nm="${__RESULT}"
   
   consul_check_key_exists "${swarm_token_nm}" 
   token_exists="${__RESULT}"
   
   if [[ 'false' == "${token_exists}" ]]
   then
      echo 'ERROR: swarm join token not found.'
      exit 1
   fi
   
   consul_get_key "${swarm_token_nm}" 
   swarm_token="${__RESULT}"   
   get_datacenter_application_advertise_interface "${INSTANCE_KEY}" "${SWARM_KEY}" 'Ip'
   advertise_addr="${__RESULT}"
   get_datacenter_application_port "${INSTANCE_KEY}" "${SWARM_KEY}" 'ClusterPort'
   cluster_port="${__RESULT}"   
   
   if [[ -n "${swarm_token}" ]]
   then
      docker_swarm_join "${swarm_token}" "${advertise_addr}" "${cluster_port}"
   
      echo 'The node successfully joined the swarm.'   
   else
      echo 'ERROR: swarm token not found.'
      exit 1 
   fi
fi

if [[ 'manager' == "${node_mode}" ]]
then
   get_datacenter_network "${OVERLAYNET_KEY}" 'Name' 
   overlaynet_nm="${__RESULT}"
   get_datacenter_network "${OVERLAYNET_KEY}" 'Cidr' 
   overlaynet_cidr="${__RESULT}"

   echo 'Creating overlay network ...'
   
   docker_network_create "${overlaynet_nm}" "${overlaynet_cidr}" 'overlay'
   
   echo 'Overlay network sucessfully created.'
fi

# A worker host machine will recognize this network only when it hosts a container that connects into this overlay network.
# In a manager host machine the network is always visible.

docker_networks_display

echo


