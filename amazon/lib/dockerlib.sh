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
         "${registry_uri}" > /dev/null  
       
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
       
   docker logout "${registry_uri}" > /dev/null  
       
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: logging out from the AWS registry.'
   fi     
            
   return "${exit_code}"
}

#===============================================================================
# Checks if a local image exists.
#
# Globals:
#  None
# Arguments:
# +repository -- the image repository.
# +tag        -- the image tag.
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
   local -r repository="${1}"
   local -r tag="${2}"
   local exists='true'

   if [[ "$(docker images -q "${repository}":"${tag}")" == "" ]]
   then
      exists='false'
   fi 
   
   __RESULT="${exists}"

   return "${exit_code}"
}

#===============================================================================
# Builds an image from a Docker file.
#
# Globals:
#  None
# Arguments:
# +repository -- the image repository.
# +tag        -- the image tag.
# +docker_ctx -- the directory containing the Docker file.
# +build_args -- optional, a sequence of var=value pairs separated by white 
#                space, eg: home=/vagrant/home port=80 user=vagrant  
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
   local cmd=''
   
   __get_docker_build_command "${@}"
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: building Docker command.'
      return "${exit_code}"
   fi
   
   cmd="${__RESULT}"

   eval "${cmd}" 
   exit_code=$?     
            
   return "${exit_code}"
}

function __get_docker_build_command()
{
   __RESULT=''
   local exit_code=0
   local -r repository="${1}"
   local -r tag="${2}"
   local -r docker_ctx="${3}"
   local build_args=''
   local cmd=''
   
   if [[ $# -eq 4 ]]
   then
      build_args="${4}"
   fi
      
   cmd="docker build -t=${repository}:${tag} ${docker_ctx}"
   
   if [[ -n "${build_args}" ]]
   then
      IFS=' ' read -r -a array <<< "${build_args}"
       
      for element in "${array[@]}"
      do
         cmd+=" --build-arg ${element}"   
      done       
   fi
   
   __RESULT="${cmd}"
   
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
# +repository        -- the source image repository.
# +tag               -- the source image tag.
# +target_repository -- the target image repository.
# +target_tag        -- the target image tag.
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
   local -r repository="${1}"
   local -r tag="${2}"
   local -r target_repository="${3}"
   local -r target_tag="${4}"
     
   # To push an image to a private registry and not the central Docker registry 
   # you must tag it with the registry hostname and port (if needed).
   docker tag "${repository}":"${tag}" "${target_repository}":"${target_tag}" > /dev/null 
       
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
# +repository -- the image repository.
# +tag        -- the image tag.
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
   local -r repository="${1}"
   local -r tag="${2}"

   docker push "${repository}":"${tag}" > /dev/null   
       
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
# +repository -- the image repository.
# +tag        -- the image tag.
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
   local -r repository="${1}"
   local -r tag="${2}"
   
   docker pull "${repository}":"${tag}" > /dev/null   
       
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: pulling the image from the registry.'
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
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: looking for network.'
      return "${exit_code}"
   fi     
   
   if [[ -n "${net}" ]]
   then
      exists='true'
   fi
   
   __RESULT="${exists}"
            
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
   local exists='false'
   local container_id=''
   
   container_id="$(docker container ls -a --filter "name=${container_nm}" --format "{{.ID}}")"

   if [[ -n "${container_id}" ]]
   then
      exists='true'
   fi 
   
   __RESULT="${exists}"

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

   docker stop "${container_nm}" > /dev/null       
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

   docker rm "${container_nm}" > /dev/null     
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting container.'
   fi     
            
   return "${exit_code}"
}  

#===============================================================================
# Runs a Jenkins container exposing port 80. The Jenkins status is persisted on 
# host by mounting a volume in the container. 
# docker.sock it’s the Unix socket the Docker daemon listens on by default and
# it's mounted in the container.
# 
# Globals:
#  None
# Arguments:
# +container_nm    -- the container name.
# +img_repository  -- image name.
# +img_tag         -- image tag.
# +jenkins_port    -- website HTTP port.
# +host_volume_dir -- Jenkins home volume mounted to the container.
#
# Returns:      
#  none.  
#===============================================================================
function docker_run_jenkins_container()
{
   if [[ $# -lt 5 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
  
   local exit_code=0
   local -r container_nm="${1}"
   local -r img_repository="${2}"
   local -r img_tag="${3}" 
   local -r jenkins_port="${4}"  
   local -r host_volume_dir="${5}"

   docker run -d --name "${container_nm}" \
              -v "${host_volume_dir}":/var/jenkins_home \
              -v /var/run/docker.sock:/var/run/docker.sock \
              -p "${jenkins_port}":8080 \
              -p 5000:5000 \
              "${img_repository}":"${img_tag}" > /dev/null        
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: running Jenkins container.'
   fi     
            
   return "${exit_code}"
}  
  
#===============================================================================
# Runs a Nginx container exposing port 80. 
# The website directory is a host volume mounted in the container.
# 
# Globals:
#  None
# Arguments:
# +container_nm         -- the container name.
# +img_repository       -- image name.
# +img_tag              -- image tag.
# +port                 -- website HTTP port.
# +host_volume_dir      -- website volume mounted to the container.
# +container_volume_dir -- website directory in the container.
# Returns:      
#  none.  
#===============================================================================
function docker_run_nginx_container()
{
   if [[ $# -lt 6 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r container_nm="${1}"
   local -r img_repository="${2}"
   local -r img_tag="${3}"   
   local -r port="${4}"
   local -r host_volume_dir="${5}"   
   local -r container_volume_dir="${6}" 

   docker run -d --name "${container_nm}" \
              -v "${host_volume_dir}":"${container_volume_dir}":ro \
              -p "${port}":"${port}" \
              "${img_repository}":"${img_tag}" > /dev/null       
              
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: running Nginx container.'
   fi     
            
   return "${exit_code}"
}    
  
#===============================================================================
# Runs a Redis database container exposing port 6379. 
# 
# Globals:
#  None
# Arguments:
# +container_nm   -- the container name.
# +img_repository -- Nginx image name.
# +img_tag        -- Nginx image tag.
# +port           -- database port.
# +network_nm     -- container network name.
# Returns:      
#  none.  
#===============================================================================
function docker_run_redis_container()
{
   if [[ $# -lt 5 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r container_nm="${1}"
   local -r img_repository="${2}"
   local -r img_tag="${3}"   
   local -r port="${4}"
   local -r network_nm="${5}"   

   docker run -d --name "${container_nm}" \
              -p "${port}":"${port}" \
              --net "${network_nm}" \
              "${img_repository}":"${img_tag}" > /dev/null  
                   
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: running Redis container.'
   fi     
            
   return "${exit_code}"
}   
  
#===============================================================================
# Runs a Sinatra container exposing port 4567. 
# The Sinatra sources and website are in a host volume mounted in the container.
# 
# Globals:
#  None
# Arguments:
# +container_nm         -- the container name.
# +img_repository       -- image name.
# +img_tag              -- image tag.
# +port                 -- website HTTP port.
# +host_volume_dir      -- Sinatra volume mounted in the container.
# +container_volume_dir -- sinatra directory in the container.
# +network_nm           -- container network name.
# Returns:      
#  none.  
#===============================================================================
function docker_run_sinatra_container()
{
   if [[ $# -lt 7 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r container_nm="${1}"
   local -r img_repository="${2}"
   local -r img_tag="${3}"   
   local -r port="${4}"
   local -r host_volume_dir="${5}"   
   local -r container_volume_dir="${6}" 
   local -r network_nm="${7}"   
 
   docker run -d --name "${container_nm}" \
              -v "${host_volume_dir}":"${container_volume_dir}":ro \
              -p "${port}":"${port}" \
              "${img_repository}":"${img_tag}" \
              --net "${network_nm}" > /dev/null                
                  
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: running Sinatra container.'
   fi     
            
   return "${exit_code}"
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
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      return "${exit_code}"
   fi     
   
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

