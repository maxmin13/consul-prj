#!/usr/bin/bash

set -o errexit
## turn on -e in subshells
## shopt -s inherit_errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: docker.sh
#   DESCRIPTION: Docker commands.
#       GLOBALS: None
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#===============================================================================

#===============================================================================
# Authenticates to the Docker AWS registry.
# After authentication, you can use the Docker client to push and pull images 
# from the registry.
#
# Globals:
#  None
# Arguments:
# +registry_uri  -- ECR registry url.
# +session_token -- ECR authorization token.
# Returns:      
#  None 
#===============================================================================
function docker_login_ecr_registry()
{
if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   local exit_code=0
   local registry_uri="${1}"
   local session_token="${2}"

   # Docker CLI doesn’t support native IAM authentication methods, we will use an 
   # authorization token to login, which is provided by the aws ecr 
   # get-login-password command on Linux
   echo $"${session_token}" | \
      docker login \
         --username 'AWS' \
         --password-stdin \
         "${registry_uri}"  
       
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: logging into AWS registry.'
   fi     
            
   return "${exit_code}"
}

#===============================================================================
# Logout from the Docker AWS registry.
#
# Globals:
#  None
# Arguments:
# +registry_uri -- ECR registry url.
# Returns:      
#  None 
#===============================================================================
function docker_logout_ecr_registry()
{
if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   local exit_code=0
   local registry_uri="${1}"
       
   docker logout "${registry_uri}"  
       
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: logging out from the AWS registry.'
   fi     
            
   return "${exit_code}"
}

#===============================================================================
# Checks if an image exists locally.
#
# Globals:
#  None
# Arguments:
# +repository_nm -- the image's repository.
# +tag           -- the image's tag.
# Returns:      
#  true/false in the global __RESULT variable.
#===============================================================================
function docker_check_img_exists()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT='false'
   local exit_code=0
   local -r repository_nm="${1}"
   local -r tag="${2}"
   local image_id=''
   
   image_id="$(docker images -q "${repository_nm}":"${tag}")"
   
   if [[ -n "${image_id}" ]]
   then
      __RESULT='true'
   else
      __RESULT='false'
   fi 
   
   return "${exit_code}"
}

#===============================================================================
# Builds an image from a Docker file.
#
# Globals:
#  None
# Arguments:
# +repository_nm -- the image's repository.
# +tag           -- the image's tag.
# +docker_ctx    -- the directory containing the Docker file.
# Returns:      
#  None
#===============================================================================
function docker_build_img()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r repository="${1}"
   local -r tag="${2}"
   local -r docker_ctx="${3}"
   
   docker build -t="${repository}":"${tag}" "${docker_ctx}"
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: building Docker image.'
   fi
            
   return "${exit_code}"
}

#===============================================================================
# Deletes an image.
#
# Globals:
#  None
# Arguments:
# +repository -- the image repository.
# +tag        -- the image tag.
# Returns:      
#  None
#===============================================================================
function docker_delete_img()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r repository="${1}"
   local -r tag="${2}"

   docker rmi "${repository}":"${tag}"

   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting image.'
   fi     
            
   return "${exit_code}"
}

#===============================================================================
# Tags an image with its repository URI.
# Creates a tag TARGET_IMAGE that refers to SOURCE_IMAGE
#
# Globals:
#  None
# Arguments:
# +repository_nm        -- the source image repository.
# +tag                  -- the source image tag.
# +target_repository_nm -- the target image repository.
# +target_tag           -- the target image tag.
# Returns:      
#  none.  
#===============================================================================
function docker_tag_image()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r repository_nm="${1}"
   local -r tag="${2}"
   local -r target_repository_nm="${3}"
   local -r target_tag="${4}"
     
   # To push an image to a private registry and not the central Docker registry 
   # you must tag it with the registry hostname and port (if needed).
   docker tag "${repository_nm}":"${tag}" "${target_repository_nm}":"${target_tag}" 
       
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: tagging the image.'
   fi     
            
   return "${exit_code}"
}

#===============================================================================
# Pushes a local image to a repository. 
# Docker tags the image with its repository URI, the pushes the image to the 
# repository.
# Globals:
#  None
# Arguments:
# +repository_nm -- the image's repository.
# +tag           -- the image's tag.
# Returns:      
#  none.  
#===============================================================================
function docker_push_image()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r repository_nm="${1}"
   local -r tag="${2}"

   docker push "${repository_nm}":"${tag}"   
       
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: pushing the image to the registry.'
   fi     
            
   return "${exit_code}"
}

#===============================================================================
# Pulls an image from a repository. 
# 
# Globals:
#  None
# Arguments:
# +repository_nm -- the image's repository.
# +tag           -- the image's tag.
# Returns:      
#  none.  
#===============================================================================
function docker_pull_image()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r repository_nm="${1}"
   local -r tag="${2}"
   
   docker pull "${repository_nm}":"${tag}"   
       
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: pulling the image from the registry.'
   fi     
            
   return "${exit_code}"
}

#===============================================================================
# Checks if a contaner exists.
#
# Globals:
#  None
# Arguments:
# +container_nm -- the container name.
# Returns:      
#  true/false in the __RESULT variable.
#===============================================================================
function docker_check_container_exists()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT='false'
   local exit_code=0
   local -r container_nm="${1}"
   local container_id=''
   
   container_id="$(docker container ls -a --filter "name=${container_nm}" --format "{{.ID}}")"

   if [[ -n "${container_id}" ]]
   then
      __RESULT='true'
   else
      __RESULT='false'
   fi 

   return "${exit_code}"
}

#===============================================================================
# Stops a container. 
# 
# Globals:
#  None
# Arguments:
# +container_nm -- the container name.
# Returns:      
#  none.  
#===============================================================================
function docker_stop_container()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r container_nm="${1}"

   docker stop "${container_nm}"       
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: stopping container.'
   fi     
            
   return "${exit_code}"
}

#===============================================================================
# Deletes a container. 
# 
# Globals:
#  None
# Arguments:
# +container_nm -- the container name.
# Returns:      
#  none.  
#===============================================================================
function docker_delete_container()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r container_nm="${1}"

   docker rm "${container_nm}"     
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting container.'
   fi     
            
   return "${exit_code}"
}  

#===============================================================================
# Runs a container.
# The function gets the values from the file service_consts.json.
#
# Globals:
#  None
# Arguments:
# +service_key  -- key into the file service_consts.json.
# +container_nm -- name assingned to the running container.
# +deploy_dir   -- name of the directory where the container's application is 
#                  deployed.
# Returns:      
#  None
#===============================================================================
function docker_run_container()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r service_key="${1}"
   local -r container_nm="${2}"
   local cmd=''
   
   cmd="docker run -d --name ${container_nm}"
   
   # get the container network.
   get_service_container "${service_key}" 'Network'
   local network_nm="${__RESULT}"
   
   if [[ -n "${network_nm}" ]]
   then
      cmd+=" --net ${network_nm}"   
   fi
   
   # get the container volume.
   get_service_application "${service_key}" 'HostVolume'
   local host_dir="${__RESULT}"
   get_service_application "${service_key}" 'ContainerVolume'
   local container_dir="${__RESULT}"  

   if [[ -n "${host_dir}" && -n "${container_dir}" ]]
   then  
      cmd+=" -v ${host_dir}:${container_dir}"  
   fi
   
   get_service_application "${service_key}" 'MountMode'
   local v_mount_mode="${__RESULT}"
   
   if [[ -n "${v_mount_mode}" ]]
   then  
      cmd+=":${v_mount_mode}"  
   fi  
   
   # mount the Docker socket of the host in the container.
   get_service_engine "${service_key}" 'HostSocket'
   local host_socket="${__RESULT}"
   get_service_engine "${service_key}" 'ContainerSocket'
   local container_socket="${__RESULT}"  
      
   if [[ -n "${host_socket}" && -n "${container_socket}" ]]
   then  
      cmd+=" -v ${host_socket}:${container_socket}"  
   fi
   
   get_service_engine "${service_key}" 'MountMode'
   local s_mount_mode="${__RESULT}"
   
   if [[ -n "${s_mount_mode}" ]]
   then  
      cmd+=":${s_mount_mode}"  
   fi 
   
   # get the container port.
   get_service_application "${service_key}" 'HostPort'
   local host_port="${__RESULT}"
   get_service_application "${service_key}" 'ContainerPort'
   local container_port="${__RESULT}"
   
   if [[ -n "${host_port}" && -n "${container_port}" ]]
   then  
      cmd+=" -p ${host_port}:${container_port}"
   fi
   
   # get image name and tag
   get_service_image "${service_key}" 'Name'
   local image_nm="${__RESULT}"
   get_datacenter 'Region'
   region="${__RESULT}"
   ecr_get_registry_uri "${region}"
   registry_uri="${__RESULT}"
   ecr_get_repostory_uri "${image_nm}" "${registry_uri}"
   repository_uri="${__RESULT}"
   get_service_image "${service_key}" 'Tag'
   local image_tag="${__RESULT}"
   
   cmd+=" ${repository_uri}:${image_tag}" 

   # get the command to run in the container when it starts.
   get_service_container "${service_key}" "Cmd"
   local command="${__RESULT}"
   
   if [[ -n "${command}" ]]
   then
      cmd+=" ${command}"   
   fi
   
   echo "Running:"
   echo "${cmd}"
   
   eval "${cmd}"
            
   return "${exit_code}"
}

#===============================================================================
# Runs hello world container.
# 
# Globals:
#  none
# Arguments:
#  none
# Returns:      
#  none.  
#===============================================================================
function docker_run_helloworld_container()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   local -r container_nm="${1}"
   
   docker run --name "${container_nm}" -i -t hello-world
}     

#===============================================================================
# Runs a command in a running container.
# 
# Globals:
#  None
# Arguments:
#  +container_nm -- the container name.
#  +command      -- the command to run in the container.
#  +options      -- the command's options.
# Returns:      
#  none.  
#===============================================================================
function docker_exec()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   local exit_code=0
   local -r container_nm="${1}"
   local -r command="${2}"
   local options=''
   
   if [[ 3 -eq "${#}" ]]
   then
      options="${3}"
   fi

   docker exec "${container_nm}" "${command}" "${options}" 
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: running Docker command.'
   fi     
            
   return "${exit_code}"
} 

#===============================================================================
# Creates a Docker network and assign a network segment to it.  
#
# Overlay network:
# all swarm service management traffic is encrypted by default, manager nodes in 
# the swarm rotate the key used to encrypt gossip data every 12 hours.
# To encrypt application data as well, add '--opt encrypted' when creating the 
# overlay network. This enables IPSEC encryption at the level of the vxlan. 
# This encryption imposes a non-negligible performance penalty, so you should 
# test this option before using it in production.
#
# Useful commands:
#
#  sudo docker network ls
#  sudo docker network inspect <network name>
# 
# Globals:
#  None
# Arguments:
# +network_nm  -- the network name.
# +driver      -- the network type, eg. bridge, overlay.
# +subnet_cidr -- subnet in CIDR format that represents a network segment.
# +gateway_add -- IPv4 address of the gateway.
# Returns:      
#  none.  
#===============================================================================
function docker_network_create()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r network_nm="${1}" 
   local -r driver="${2}"  
   local -r subnet_cidr="${3}"
   local -r gateway_add="${4}"

   docker network create "${network_nm}" \
                         --subnet "${subnet_cidr}" \
                         --gateway "${gateway_add}" \
                         --driver "${driver}" \
                         --attachable        
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: creating network.'
   fi     
            
   return "${exit_code}"
} 

#===============================================================================
# Removes a Docker network.  
#
# Globals:
#  None
# Arguments:
# +network_nm -- the network name.
# Returns:      
#  none.  
#===============================================================================
function docker_network_remove()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r network_nm="${1}" 

   docker network remove "${network_nm}"         
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: removing network.'
   fi     
            
   return "${exit_code}"
} 

#===============================================================================
# Check if a nework exists.  
# 
# Globals:
#  None
# Arguments:
# +network_nm -- the network name.
# Returns:      
#  true/false in the __RESULT variable.
#===============================================================================
function docker_network_exists()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT='false'
   local exit_code=0
   local -r network_nm="${1}"  
   local exists='false'
   local net=''

   net="$(docker network ls | awk -v nm="${network_nm}" '$2==nm {print $2}')"
   
   if [[ -n "${net}" ]]
   then
      exists='true'
   fi
   
   __RESULT="${exists}"
            
   return "${exit_code}"
}

#===============================================================================
# Returns 'active' if the Docker node is part of a swarm, 'inactive' if not.  
# 
# Globals:
#  None
# Arguments:
#  none.
# Returns:      
#  active/inactive in the __RESULT variable.
#===============================================================================
function docker_swarm_status()
{
   if [[ $# -lt 0 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT='false'
   local exit_code=0
   local swarm_status=''

   swarm_status="$(docker info | awk -v nm="Swarm" '$1~nm {print $2}')"   
   
   __RESULT="${swarm_status}"
            
   return "${exit_code}"
} 

#===============================================================================
# Initializes a swarm.  
# 
# Globals:
#  None
# Arguments:
#  none.
# Returns:      
#  none.  
#===============================================================================
function docker_swarm_init()
{
   local exit_code=0

   docker swarm init      
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: initializing swarm.'
   fi     
            
   return "${exit_code}"
} 

