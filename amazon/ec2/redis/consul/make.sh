#!/bin/bash

# shellcheck disable=SC2015

##########################################################################################################
#
# Consul is a datacenter runtime that provides service discovery, configuration, and orchestration.
# The script installs Consul in the Redis database instance and runs an agent in client mode.
# Consul agents exchange messages on the 'main-subnet' network.
# 
##########################################################################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR=/home/"${USER_NM}"/script
CONSUL_SECRET_NM='consulkey'

####
STEP 'Redis Consul'
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

get_instance_id "${REDIS_INST_NM}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* ERROR: Redis box not found.'
   exit 1
fi

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${REDIS_INST_NM}"
   instance_st="${__RESULT}"
   
   if [[ 'running' == "${instance_st}" ]]
   then
      echo "* Redis box ready (${instance_st})."
   else
      echo "* ERROR: Redis box is not ready. (${instance_st})."
      
      exit 1
   fi
fi

get_security_group_id "${REDIS_INST_SEC_GRP_NM}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* ERROR: security group not found.'
   exit 1
else
   echo "* security group ID: ${sgp_id}."
fi


# Get the public IP address assigned to the instance. 
get_public_ip_address_associated_with_instance "${REDIS_INST_NM}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo '* ERROR: public IP address not found.'
   exit 1
else
   echo "* public IP address: ${eip}."
fi

# Removing old files
# shellcheck disable=SC2115
redis_tmp_dir="${TMP_DIR}"/consul
rm -rf  "${redis_tmp_dir:?}"
mkdir -p "${redis_tmp_dir}"

echo

#
# Permissions.
#

check_role_has_permission_policy_attached "${REDIS_AWS_ROLE_NM}" "${SECRETSMANAGER_POLICY_NM}"
is_permission_policy_associated="${__RESULT}"

if [[ 'false' == "${is_permission_policy_associated}" ]]
then
   echo 'Associating permission policy the instance role ...'

   attach_permission_policy_to_role "${REDIS_AWS_ROLE_NM}" "${SECRETSMANAGER_POLICY_NM}"

   echo 'Permission policy associated to the role.'  
else
   echo 'WARN: permission policy already associated to the role.'
fi 

#
# Firewall
#

check_access_is_granted "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log  
   
   echo "Access granted on "${SHARED_INST_SSH_PORT}" tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${SHARED_INST_SSH_PORT} tcp 0.0.0.0/0."
fi

check_access_is_granted "${sgp_id}" "${REDIS_CONSUL_SERVER_SERF_LAN_PORT}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${REDIS_CONSUL_SERVER_SERF_LAN_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log 
   
   echo "Access granted on "${REDIS_CONSUL_SERVER_SERF_LAN_PORT}" tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${REDIS_CONSUL_SERVER_SERF_LAN_PORT} tcp 0.0.0.0/0."
fi

check_access_is_granted "${sgp_id}" "${REDIS_CONSUL_SERVER_SERF_LAN_PORT}" 'udp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${REDIS_CONSUL_SERVER_SERF_LAN_PORT}" 'udp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log 
   
   echo "Access granted on "${REDIS_CONSUL_SERVER_SERF_LAN_PORT}" tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${REDIS_CONSUL_SERVER_SERF_LAN_PORT} udp 0.0.0.0/0."
fi

check_access_is_granted "${sgp_id}" "${REDIS_CONSUL_SERVER_SERF_WAN_PORT}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${REDIS_CONSUL_SERVER_SERF_WAN_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log 
   
   echo "Access granted on "${REDIS_CONSUL_SERVER_SERF_WAN_PORT}" tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${REDIS_CONSUL_SERVER_SERF_WAN_PORT} tcp 0.0.0.0/0."
fi

check_access_is_granted "${sgp_id}" "${REDIS_CONSUL_SERVER_SERF_WAN_PORT}" 'udp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${REDIS_CONSUL_SERVER_SERF_WAN_PORT}" 'udp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log 
   
   echo "Access granted on "${REDIS_CONSUL_SERVER_SERF_WAN_PORT}" tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${REDIS_CONSUL_SERVER_SERF_WAN_PORT} udp 0.0.0.0/0."
fi

check_access_is_granted "${sgp_id}" "${REDIS_CONSUL_SERVER_RPC_PORT}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${REDIS_CONSUL_SERVER_RPC_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log 
   
   echo "Access granted on "${REDIS_CONSUL_SERVER_RPC_PORT}" tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${REDIS_CONSUL_SERVER_RPC_PORT} tcp 0.0.0.0/0."
fi

check_access_is_granted "${sgp_id}" "${REDIS_CONSUL_SERVER_HTTP_PORT}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${REDIS_CONSUL_SERVER_HTTP_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log 
   
   echo "Access granted on "${REDIS_CONSUL_SERVER_HTTP_PORT}" tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${REDIS_CONSUL_SERVER_HTTP_PORT} tcp 0.0.0.0/0."
fi

check_access_is_granted "${sgp_id}" "${REDIS_CONSUL_SERVER_DNS_PORT}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${REDIS_CONSUL_SERVER_DNS_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log 
   
   echo "Access granted on "${REDIS_CONSUL_SERVER_DNS_PORT}" tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${REDIS_CONSUL_SERVER_DNS_PORT} tcp 0.0.0.0/0."
fi

check_access_is_granted "${sgp_id}" "${REDIS_CONSUL_SERVER_DNS_PORT}" 'udp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${REDIS_CONSUL_SERVER_DNS_PORT}" 'udp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log 
   
   echo "Access granted on "${REDIS_CONSUL_SERVER_DNS_PORT}" tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${REDIS_CONSUL_SERVER_DNS_PORT} udp 0.0.0.0/0."
fi

private_key_file="${ACCESS_DIR}"/"${REDIS_INST_KEY_PAIR_NM}" 
wait_ssh_started "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}"

ssh_run_remote_command "rm -rf ${SCRIPTS_DIR} && mkdir -p ${SCRIPTS_DIR}" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}"  
    
# Prepare the scripts to run on the server.

echo 'Provisioning Consul scripts ...'

sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}")/g" \
    -e "s/SEDdtc_regionSED/${DTC_REGION}/g" \
    -e "s/SEDinstance_eip_addressSED/${eip}/g" \
    -e "s/SEDinstance_private_addressSED/${REDIS_INST_PRIVATE_IP}/g" \
    -e "s/SEDconsul_config_file_nmSED/consul-client.json/g" \
    -e "s/SEDconsul_service_file_nmSED/consul.service/g" \
    -e "s/SEDconsul_http_portSED/${REDIS_CONSUL_SERVER_HTTP_PORT}/g" \
    -e "s/SEDconsul_dns_portSED/${REDIS_CONSUL_SERVER_DNS_PORT}/g" \
    -e "s/SEDagent_modeSED/client/g" \
    -e "s/SEDconsul_secret_nmSED/${CONSUL_SECRET_NM}/g" \
       "${SERVICES_DIR}"/consul/consul.sh > "${redis_tmp_dir}"/consul.sh  
     
echo 'consul.sh ready.'   

sed -e "s/SEDbind_addressSED/${REDIS_INST_PRIVATE_IP}/g" \
    -e "s/SEDbootstrap_expectSED/1/g" \
    -e "s/SEDstart_join_bind_addressSED/${ADMIN_INST_PRIVATE_IP}/g" \
    "${SERVICES_DIR}"/consul/consul-client.json > "${redis_tmp_dir}"/consul-client.json
    
echo 'consul-client.json ready.'      
      
scp_upload_files "${private_key_file}" "${eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}" \
    "${redis_tmp_dir}"/consul.sh \
    "${redis_tmp_dir}"/consul-client.json \
    "${SERVICES_DIR}"/consul/consul.service \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/secretsmanager.sh
         
echo 'Consul scripts provisioned.'
echo

ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR}" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}"      

ssh_run_remote_command_as_root "${SCRIPTS_DIR}/consul.sh" \
    "${private_key_file}" \
    "${eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" >> "${LOGS_DIR}"/redis.log && echo 'Consul client successfully installed.' ||
    {    
       echo 'The role may not have been associated to the profile yet.'
       echo 'Let''s wait a bit and check again (first time).' 
      
       wait 180  
      
       echo 'Let''s try now.' 
    
       ssh_run_remote_command_as_root "${SCRIPTS_DIR}/consul.sh" \
          "${private_key_file}" \
          "${eip}" \
          "${SHARED_INST_SSH_PORT}" \
          "${USER_NM}" \
          "${USER_PWD}" >> "${LOGS_DIR}"/redis.log && echo 'Consul client successfully installed.' ||
          {
              echo 'ERROR: the problem persists after 3 minutes.'
              exit 1          
          }
    }
    
ssh_run_remote_command "rm -rf ${SCRIPTS_DIR}" \
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
   echo 'Detaching permission policy from the role ...'

   detach_permission_policy_from_role "${REDIS_AWS_ROLE_NM}" "${SECRETSMANAGER_POLICY_NM}"
      
   echo 'Permission policy detached.'
else
   echo 'WARN: permission policy already detached from the role.'
fi 

## 
## Firewall.
##

check_access_is_granted "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'true' == "${is_granted}" ]]
then
   revoke_access_from_cidr "${sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/redis.log  
   
   echo "Access revoked on "${SHARED_INST_SSH_PORT}" tcp 0.0.0.0/0."
else
   echo "WARN: access already revoked ${SHARED_INST_SSH_PORT} tcp 0.0.0.0/0."
fi 

# Removing old files
# shellcheck disable=SC2115
rm -rf  "${redis_tmp_dir:?}"


