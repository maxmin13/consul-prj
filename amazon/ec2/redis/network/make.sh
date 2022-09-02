#!/bin/bash

# shellcheck disable=SC2015

##########################################################################################################
# 
# The script configures the Docker engine to use the Key-Value Store in the Admin host for Clustering and
# creates a Docker overlay network.
#
# TODO building after Consul cluster is in plade TODO
# 
##########################################################################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR=/home/"${USER_NM}"/script

####
STEP 'Redis DB network'
####

get_datacenter_id "${DTC_NM}"
dtc_id="${__RESULT}"
  
if [[ -z "${dtc_id}" ]]
then
   echo '* ERROR: data center not found.'
   exit 1
else
   echo "* data center ID: ${dtc_id}."
fi

get_subnet_id "${DTC_SUBNET_MAIN_NM}"
subnet_id="${__RESULT}"

if [[ -z "${subnet_id}" ]]
then
   echo '* ERROR: main subnet not found.'
   exit 1
else
   echo "* main subnet ID: ${subnet_id}."
fi

get_instance_id "${ADMIN_INST_NM}"
admin_instance_id="${__RESULT}"

if [[ -z "${admin_instance_id}" ]]
then
   echo '* ERROR: Admin box not found.'
   exit 1
fi

if [[ -n "${admin_instance_id}" ]]
then
   get_instance_state "${ADMIN_INST_NM}"
   admin_instance_st="${__RESULT}"
   
   if [[ 'running' == "${admin_instance_st}" ]]
   then
      echo "* Admin box ready (${admin_instance_st})."
   else
      echo "* ERROR: Admin box is not ready. (${admin_instance_st})."
      
      exit 1
   fi
fi

get_instance_id "${REDIS_INST_NM}"
redis_instance_id="${__RESULT}"

if [[ -z "${redis_instance_id}" ]]
then
   echo '* ERROR: Redis box not found.'
   exit 1
fi

if [[ -n "${redis_instance_id}" ]]
then
   get_instance_state "${REDIS_INST_NM}"
   redis_instance_st="${__RESULT}"
   
   if [[ 'running' == "${redis_instance_st}" ]]
   then
      echo "* Redis box ready (${redis_instance_st})."
   else
      echo "* ERROR: Redis box is not ready. (${redis_instance_st})."
      
      exit 1
   fi
fi

get_security_group_id "${REDIS_INST_SEC_GRP_NM}"
redis_sgp_id="${__RESULT}"

if [[ -z "${redis_sgp_id}" ]]
then
   echo '* ERROR: Redis security group not found.'
   exit 1
else
   echo "* Redis security group ID: ${redis_sgp_id}."
fi

# Removing old files
# shellcheck disable=SC2115
redis_tmp_dir="${TMP_DIR}"/redis
rm -rf  "${redis_tmp_dir:?}"
mkdir -p "${redis_tmp_dir}"

echo

set +e
allow_access_from_cidr "${redis_sgp_id}" "${NETWORK_OVERLAY_CLUSTER_MANAGEMENT_COMMS_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log

# Firewall rules for Docker daemons using overlay networks
allow_access_from_cidr "${redis_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log
allow_access_from_cidr "${redis_sgp_id}" "${NETWORK_OVERLAY_NODES_COMMS_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log
allow_access_from_cidr "${redis_sgp_id}" "${NETWORK_OVERLAY_NODES_COMMS_PORT}" 'udp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log
allow_access_from_cidr "${redis_sgp_id}" "${NETWORK_OVERLAY_TRAFFIC_PORT}" 'udp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log
set -e
   
echo 'Granted SSH access to the Redis box.'

# 
# Redis box
#

# Get the public IP address assigned to the instance. 
get_public_ip_address_associated_with_instance "${REDIS_INST_NM}"
redis_eip="${__RESULT}"

echo "Redis box public address: ${redis_eip}."

#
echo 'Provisioning the Redis instance ...'
# 

private_key_file="${ACCESS_DIR}"/"${REDIS_INST_KEY_PAIR_NM}" 
wait_ssh_started "${private_key_file}" "${redis_eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}"

ssh_run_remote_command "rm -rf ${SCRIPTS_DIR} && mkdir -p ${SCRIPTS_DIR}" \
    "${private_key_file}" \
    "${redis_eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}"
    
# Prepare the scripts to run on the server.

echo 'Provisioning network scripts ...'

sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}")/g" \
    -e "s/SEDsina_redis_network__nmSED/${SINA_REDIS_NETWORK_NM}/g" \
    -e "s/SEDsina_redis_network_cidrSED/$(escape "${SINA_REDIS_NETWORK_CIDR}")/g" \
    -e "s/SEDsina_redis_network_gateSED/${SINA_REDIS_NETWORK_GATE}/g" \
       "${SERVICES_DIR}"/docker/overlay.sh > "${redis_tmp_dir}"/overlay.sh  
     
echo 'overlay.sh ready.'      
       
scp_upload_files "${private_key_file}" "${redis_eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}" \
    "${LIBRARY_DIR}"/constants/app_consts.sh \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${redis_tmp_dir}"/overlay.sh 
         
echo 'Network scripts provisioned.'
echo

ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR}" \
    "${private_key_file}" \
    "${redis_eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}"      

ssh_run_remote_command_as_root "${SCRIPTS_DIR}/overlay.sh" \
    "${private_key_file}" \
    "${redis_eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" && echo 'Network successfully installed.'
    
#ssh_run_remote_command "rm -rf ${SCRIPTS_DIR}" \
#    "${private_key_file}" \
#    "${redis_eip}" \
#    "${SHARED_INST_SSH_PORT}" \
#    "${USER_NM}"      

## 
## SSH Access.
##

set +e
  ###### revoke_access_from_cidr "${redis_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log
set -e

echo 'Revoked SSH access to the Redis box.'  

# Removing old files
# shellcheck disable=SC2115
rm -rf  "${redis_tmp_dir:?}"


