#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR=/home/"${USER_NM}"/script

####
STEP 'Redis Consul'
####

get_datacenter_id "${DTC_NM}"
dtc_id="${__RESULT}"
  
if [[ -z "${dtc_id}" ]]
then
   echo '* WARN: data center not found.'
else
   echo "* data center ID: ${dtc_id}."
fi

get_subnet_id "${DTC_SUBNET_MAIN_NM}"
subnet_id="${__RESULT}"

if [[ -z "${subnet_id}" ]]
then
   echo '* WARN: main subnet not found.'
else
   echo "* main subnet ID: ${subnet_id}."
fi

get_instance_id "${REDIS_INST_NM}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: Redis box not found.'
fi

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${REDIS_INST_NM}"
   instance_st="${__RESULT}"
   
   if [[ 'running' == "${instance_st}" ]]
   then
      echo "* Redis box ready (${instance_st})."
   else
      echo "* WARN: Redis box not ready (${instance_st})."
   fi
fi

get_security_group_id "${REDIS_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: security group not found.'
else
   echo "* security group ID: ${sgp_id}."
fi


# Get the public IP address assigned to the instance. 
get_public_ip_address_associated_with_instance "${REDIS_INST_NM}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo '* WARN: public IP address not found.'
else
   echo "* Public IP address ${eip}."
fi

# Removing old files
# shellcheck disable=SC2115
redis_tmp_dir="${TMP_DIR}"/consul
rm -rf  "${redis_tmp_dir:?}"
mkdir -p "${redis_tmp_dir}"

echo

if [[ -n "${instance_id}" && 'running' == "${instance_st}" ]]
then  
   #
   # Firewall
   #

   check_access_is_granted "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0'
   is_granted="${__RESULT}"

   if [[ 'false' == "${is_granted}" ]]
   then
      allow_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log  
   
      echo "Access granted on ${SHARED_INST_SSH_PORT} tcp 0.0.0.0/0."
   else
      echo "WARN: access already granted on ${SHARED_INST_SSH_PORT} tcp 0.0.0.0/0."
   fi

   private_key_file="${ACCESS_DIR}"/"${REDIS_INST_KEY_PAIR_NM}" 
   wait_ssh_started "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}"

   ssh_run_remote_command "rm -rf ${SCRIPTS_DIR:?} && mkdir -p ${SCRIPTS_DIR}"/consul \
       "${private_key_file}" \
       "${eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${USER_NM}"  
    
   # Prepare the scripts to run on the server.

   echo 'Provisioning Consul scripts ...'

   sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}"/consul)/g" \
       -e "s/SEDdtc_regionSED/${DTC_REGION}/g" \
       -e "s/SEDconsul_service_file_nmSED/consul.service/g" \
       -e "s/SEDconsul_secret_nmSED/${CONSUL_SECRET_NM}/g" \
       -e "s/SEDagent_modeSED/client/g" \
          "${SERVICES_DIR}"/consul/consul-remove.sh > "${redis_tmp_dir}"/consul-remove.sh  
     
   echo 'consul-remove.sh ready.' 

   scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}"/consul \
       "${LIBRARY_DIR}"/general_utils.sh \
       "${LIBRARY_DIR}"/secretsmanager.sh \
       "${redis_tmp_dir}"/consul-remove.sh 
         
   echo 'Consul scripts provisioned.'
   
   ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR}"/consul \
       "${private_key_file}" \
       "${eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${USER_NM}" \
       "${USER_PWD}"   

   # shellcheck disable=SC2015
   ssh_run_remote_command_as_root "${SCRIPTS_DIR}/consul/consul-remove.sh" \
       "${private_key_file}" \
       "${eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${USER_NM}" \
       "${USER_PWD}" >> "${LOGS_DIR}"/redis.log && echo 'Consul server successfully removed.' ||
       { 
          echo 'ERROR: removing Consul.'
          exit 1
       }
    
   ssh_run_remote_command "rm -rf ${SCRIPTS_DIR:?}" \
       "${private_key_file}" \
       "${eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${USER_NM}"     

   #
   # Permissions.
   #

   check_role_has_permission_policy_attached "${REDIS_AWS_ROLE_NM}" "${SECRETSMANAGER_POLICY_NM}"
   is_permission_policy_associated="${__RESULT}"

   if [[ 'true' == "${is_permission_policy_associated}" ]]
   then
      detach_permission_policy_from_role "${REDIS_AWS_ROLE_NM}" "${SECRETSMANAGER_POLICY_NM}"
      
      echo 'Permission policy detached.'
   else
      echo 'WARN: permission policy already detached from the role.'
   fi 

   #
   # Firewall rules
   #

   check_access_is_granted "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0'
   is_granted="${__RESULT}"

   if [[ 'true' == "${is_granted}" ]]
   then
      revoke_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log  
      
      echo "Access revoked on "${SHARED_INST_SSH_PORT}" tcp 0.0.0.0/0."
   else
      echo "WARN: access already revoked ${SHARED_INST_SSH_PORT} tcp 0.0.0.0/0."
   fi

   check_access_is_granted "${sgp_id}" "${REDIS_CONSUL_SERVER_SERF_LAN_PORT}" 'tcp' '0.0.0.0/0'
   is_granted="${__RESULT}"

   if [[ 'true' == "${is_granted}" ]]
   then
      revoke_access_from_cidr "${sgp_id}" "${REDIS_CONSUL_SERVER_SERF_LAN_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log 
      
      echo "Access revoked on "${REDIS_CONSUL_SERVER_SERF_LAN_PORT}" tcp 0.0.0.0/0."
   else
      echo "WARN: access already revoked ${REDIS_CONSUL_SERVER_SERF_LAN_PORT} tcp 0.0.0.0/0."
   fi

   check_access_is_granted "${sgp_id}" "${REDIS_CONSUL_SERVER_SERF_LAN_PORT}" 'udp' '0.0.0.0/0'
   is_granted="${__RESULT}"

   if [[ 'true' == "${is_granted}" ]]
   then
      revoke_access_from_cidr "${sgp_id}" "${REDIS_CONSUL_SERVER_SERF_LAN_PORT}" 'udp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log 
      
      echo "Access revoked on "${REDIS_CONSUL_SERVER_SERF_LAN_PORT}" tcp 0.0.0.0/0."
   else
      echo "WARN: access already revoked ${REDIS_CONSUL_SERVER_SERF_LAN_PORT} udp 0.0.0.0/0."
   fi

   check_access_is_granted "${sgp_id}" "${REDIS_CONSUL_SERVER_SERF_WAN_PORT}" 'tcp' '0.0.0.0/0'
   is_granted="${__RESULT}"

   if [[ 'true' == "${is_granted}" ]]
   then
      revoke_access_from_cidr "${sgp_id}" "${REDIS_CONSUL_SERVER_SERF_WAN_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log 
      
      echo "Access revoked on "${REDIS_CONSUL_SERVER_SERF_WAN_PORT}" tcp 0.0.0.0/0."
   else
      echo "WARN: access already revoked ${REDIS_CONSUL_SERVER_SERF_WAN_PORT} tcp 0.0.0.0/0."
   fi

   check_access_is_granted "${sgp_id}" "${REDIS_CONSUL_SERVER_SERF_WAN_PORT}" 'udp' '0.0.0.0/0'
   is_granted="${__RESULT}"

   if [[ 'true' == "${is_granted}" ]]
   then
      revoke_access_from_cidr "${sgp_id}" "${REDIS_CONSUL_SERVER_SERF_WAN_PORT}" 'udp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log 
      
      echo "Access revoked on "${REDIS_CONSUL_SERVER_SERF_WAN_PORT}" tcp 0.0.0.0/0."
   else
      echo "WARN: access already revoked ${REDIS_CONSUL_SERVER_SERF_WAN_PORT} udp 0.0.0.0/0."
   fi

   check_access_is_granted "${sgp_id}" "${REDIS_CONSUL_SERVER_RPC_PORT}" 'tcp' '0.0.0.0/0'
   is_granted="${__RESULT}"

   if [[ 'true' == "${is_granted}" ]]
   then
      revoke_access_from_cidr "${sgp_id}" "${REDIS_CONSUL_SERVER_RPC_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log 
      
      echo "Access revoked on "${REDIS_CONSUL_SERVER_RPC_PORT}" tcp 0.0.0.0/0."
   else
      echo "WARN: access already revoked ${REDIS_CONSUL_SERVER_RPC_PORT} tcp 0.0.0.0/0."
   fi

   check_access_is_granted "${sgp_id}" "${REDIS_CONSUL_SERVER_HTTP_PORT}" 'tcp' '0.0.0.0/0'
   is_granted="${__RESULT}"

   if [[ 'true' == "${is_granted}" ]]
   then
      revoke_access_from_cidr "${sgp_id}" "${REDIS_CONSUL_SERVER_HTTP_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log 
      
      echo "Access revoked on "${REDIS_CONSUL_SERVER_HTTP_PORT}" tcp 0.0.0.0/0."
   else
      echo "WARN: access already revoked ${REDIS_CONSUL_SERVER_HTTP_PORT} tcp 0.0.0.0/0."
   fi

   check_access_is_granted "${sgp_id}" "${REDIS_CONSUL_SERVER_DNS_PORT}" 'tcp' '0.0.0.0/0'
   is_granted="${__RESULT}"

   if [[ 'true' == "${is_granted}" ]]
   then
      revoke_access_from_cidr "${sgp_id}" "${REDIS_CONSUL_SERVER_DNS_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log 
      
      echo "Access revoked on "${REDIS_CONSUL_SERVER_DNS_PORT}" tcp 0.0.0.0/0."
   else
      echo "WARN: access already revoked ${REDIS_CONSUL_SERVER_DNS_PORT} tcp 0.0.0.0/0."
   fi

   check_access_is_granted "${sgp_id}" "${REDIS_CONSUL_SERVER_DNS_PORT}" 'udp' '0.0.0.0/0'
   is_granted="${__RESULT}"

   if [[ 'true' == "${is_granted}" ]]
   then
      revoke_access_from_cidr "${sgp_id}" "${REDIS_CONSUL_SERVER_DNS_PORT}" 'udp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log 
      
      echo "Access revoked on "${REDIS_CONSUL_SERVER_DNS_PORT}" tcp 0.0.0.0/0."
   else
      echo "WARN: access already revoked ${REDIS_CONSUL_SERVER_DNS_PORT} udp 0.0.0.0/0."
   fi

   ## Clearing
   rm -rf  "${redis_tmp_dir:?}"

   echo 'Redis Consul deleted.'
fi

echo
