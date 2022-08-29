#!/bin/bash

##############################################################################################
# Creates an AWS ECR repository for a Centos base image and a ruby base image.
##############################################################################################

# shellcheck disable=SC1091,SC2155

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

####
STEP 'AWS ECR'
####

get_instance_id "${ADMIN_INST_NM}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: Admin box not found.'
else
   get_instance_state "${ADMIN_INST_NM}"
   instance_st="${__RESULT}"
   
   echo "* Admin box ID: ${instance_id} (${instance_st})."
fi

get_security_group_id "${ADMIN_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: security group not found.'
else
   echo "* security group ID: ${sgp_id}."
fi

get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo '* WARN: public IP address not found.'
else
   echo "* public IP address: ${eip}."
fi

echo

#
# Centos 
#

# Check if an ECR repository by the name of the image exists.
set +e
ecr_check_repository_exists "${CENTOS_DOCKER_IMG_NM}"
set -e

centos_repository_exists="${__RESULT}"

if [[ 'true' == "${centos_repository_exists}" ]]
then
   ecr_delete_repository "${CENTOS_DOCKER_IMG_NM}"
   
   echo 'Centos repository deleted.'
else
   echo 'Centos repository already deleted.'
fi

#
# Ruby 
#

# Check if an ECR repository by the name of the image exists.
set +e
ecr_check_repository_exists "${RUBY_DOCKER_IMG_NM}"
set -e

ruby_repository_exists="${__RESULT}"

if [[ 'true' == "${ruby_repository_exists}" ]]
then
   ecr_delete_repository "${RUBY_DOCKER_IMG_NM}"
   
   echo 'Ruby repository deleted.'
else
   echo 'Ruby repository already deleted.'
fi

#
# Jenkins 
#

# Check if an ECR repository by the name of the image exists.
set +e
ecr_check_repository_exists "${JENKINS_DOCKER_IMG_NM}"
set -e

jenkins_repository_exists="${__RESULT}"

if [[ 'true' == "${jenkins_repository_exists}" ]]
then
   ecr_delete_repository "${JENKINS_DOCKER_IMG_NM}"
   
   echo 'Jenkins repository deleted.'
else
   echo 'Jenkins repository already deleted.'
fi

#
# Nginx 
#

# Check if an ECR repository by the name of the image exists.
set +e
ecr_check_repository_exists "${NGINX_DOCKER_IMG_NM}"
set -e

nginx_repository_exists="${__RESULT}"

if [[ 'true' == "${nginx_repository_exists}" ]]
then
   ecr_delete_repository "${NGINX_DOCKER_IMG_NM}"
   
   echo 'Nginx repository deleted.'
else
   echo 'Nginx repository already deleted.'
fi

#
# Redis 
#

# Check if an ECR repository by the name of the image exists.
set +e
ecr_check_repository_exists "${REDIS_DOCKER_IMG_NM}"
set -e

redis_repository_exists="${__RESULT}"

if [[ 'true' == "${redis_repository_exists}" ]]
then
   ecr_delete_repository "${REDIS_DOCKER_IMG_NM}"
   
   echo 'Redis repository deleted.'
else
   echo 'Redis repository already deleted.'
fi

#
# Sinatra 
#

# Check if an ECR repository by the name of the image exists.
set +e
ecr_check_repository_exists "${SINATRA_DOCKER_IMG_NM}"
set -e

sinatra_repository_exists="${__RESULT}"

if [[ 'true' == "${sinatra_repository_exists}" ]]
then
   ecr_delete_repository "${SINATRA_DOCKER_IMG_NM}"
   
   echo 'Sinatra repository deleted.'
else
   echo 'Sinatra repository already deleted.'
fi

####### TODO
####### TODO clear Admin box #######
####### TODO local images and containers ####### 
####### TODO
####### TODO

#
# Firewall.
#

set +e
revoke_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e

#
# Permissions.
#

check_role_exists "${ADMIN_AWS_ROLE_NM}"
role_exists="${__RESULT}"

if [[ 'true' == "$role_exists{}" ]]
then
   check_policy_exists "${ECR_POLICY_NM}"
   policy_exists="${__RESULT}"

   if [[ 'true' == "$policy_exists{}" ]]
   then
      check_role_has_permission_policy_attached "${ADMIN_AWS_ROLE_NM}" "${ECR_POLICY_NM}"
      is_permission_policy_associated="${__RESULT}"

      if [[ 'true' == "${is_permission_policy_associated}" ]]
      then
         detach_permission_policy_from_role "${ADMIN_AWS_ROLE_NM}" "${ECR_POLICY_NM}"
      
         echo 'Permission policy detached.'
      else
         echo 'WARN: permission policy already detached from the role.'
      fi
   fi
fi 

echo
