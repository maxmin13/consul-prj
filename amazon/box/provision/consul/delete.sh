#!/bin/bash

# shellcheck disable=SC2015

##########################################################################################################
# Consul is a datacenter runtime that provides service discovery, configuration, and orchestration.
# The script installs Consul in the Admin instance and runs a cluster with one server.
##########################################################################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# Enforce parameter
if [ "$#" -lt 1 ]; then
  echo "USAGE: instance_key"
  echo "EXAMPLE: sinatra"
  echo "Only provided $# arguments"
  exit 1
fi

instance_key="${1}"
logfile_nm="${instance_key}".log

get_user_name
user_nm="${__RESULT}"
get_user_password
user_pwd="${__RESULT}"

SCRIPTS_DIR=/home/"${user_nm}"/script

####
STEP "${instance_key} box Consul"
####

get_instance_name "${instance_key}"
instance_nm="${__RESULT}" 
get_instance_id "${instance_nm}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo "* WARN: ${instance_key} box not found."
fi

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${instance_nm}"
   instance_st="${__RESULT}"
   
   if [[ 'running' == "${instance_st}" ]]
   then
      echo "* ${instance_key} box ready (${instance_st})."
   else
      echo "* WARN: ${instance_key} box not ready. (${instance_st})."
   fi
fi

# Get the public IP address assigned to the instance. 
get_public_ip_address_associated_with_instance "${instance_nm}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo "* WARN:  ${instance_key} IP address not found."
else
   echo "* ${instance_key} IP address: ${eip}."
fi

get_security_group_name "${instance_key}"
sgp_nm="${__RESULT}"
get_security_group_id "${sgp_nm}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo "* WARN: ${instance_key} security group not found."
else
   echo "* ${instance_key} security group ID: ${sgp_id}."
fi

# Removing old files
# shellcheck disable=SC2115
tmp_dir="${TMP_DIR}"/${instance_key}/consul
rm -rf  "${tmp_dir:?}"
mkdir -p "${tmp_dir}"

echo

if [[ -n "${instance_id}" && 'running' == "${instance_st}" ]]
then
   #
   # Permissions.
   #

   get_role_name "${instance_key}"
   role_nm="${__RESULT}"
   check_role_has_permission_policy_attached "${role_nm}" "${SECRETSMANAGER_POLICY_NM}"
   is_permission_policy_associated="${__RESULT}"

   if [[ 'false' == "${is_permission_policy_associated}" ]]
   then
      echo "Associating permission policy to ${instance_key} role ..."

      attach_permission_policy_to_role "${role_nm}" "${SECRETSMANAGER_POLICY_NM}"

      echo "Permission policy associated to ${instance_key} role."
   else
      echo "Permission policy already associated to ${instance_key} role."
   fi 

   #
   # Firewall rules
   #

   get_application_port 'ssh'
   ssh_port="${__RESULT}"
   check_access_is_granted "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0'
   is_granted="${__RESULT}"

   if [[ 'false' == "${is_granted}" ]]
   then
      allow_access_from_cidr "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
       echo "Access granted on "${ssh_port}" tcp 0.0.0.0/0."
   else
      echo "WARN: access already granted ${ssh_port} tcp 0.0.0.0/0."
   fi
   
   get_application_serflanport 'consul'
   serflan_port="${__RESULT}"
   check_access_is_granted "${sgp_id}" "${serflan_port}" 'tcp' '0.0.0.0/0'
   is_granted="${__RESULT}"

   if [[ 'true' == "${is_granted}" ]]
   then
      revoke_access_from_cidr "${sgp_id}" "${serflan_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
      
      echo "Access revoked on "${serflan_port}" tcp 0.0.0.0/0."
   else
      echo "WARN: access already revoked ${serflan_port} tcp 0.0.0.0/0."
   fi

   check_access_is_granted "${sgp_id}" "${serflan_port}" 'udp' '0.0.0.0/0'
   is_granted="${__RESULT}"

   if [[ 'true' == "${is_granted}" ]]
   then
      revoke_access_from_cidr "${sgp_id}" "${serflan_port}" 'udp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
      
      echo "Access revoked on "${serflan_port}" tcp 0.0.0.0/0."
   else
      echo "WARN: access already revoked ${serflan_port} udp 0.0.0.0/0."
   fi

   get_application_serfwanport 'consul'
   serfwan_port="${__RESULT}"
   check_access_is_granted "${sgp_id}" "${serfwan_port}" 'tcp' '0.0.0.0/0'
   is_granted="${__RESULT}"

   if [[ 'true' == "${is_granted}" ]]
   then
      revoke_access_from_cidr "${sgp_id}" "${serfwan_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
      
      echo "Access revoked on "${serfwan_port}" tcp 0.0.0.0/0."
   else
      echo "WARN: access already revoked ${serfwan_port} tcp 0.0.0.0/0."
   fi

   check_access_is_granted "${sgp_id}" "${serfwan_port}" 'udp' '0.0.0.0/0'
   is_granted="${__RESULT}"

   if [[ 'true' == "${is_granted}" ]]
   then
      revoke_access_from_cidr "${sgp_id}" "${serfwan_port}" 'udp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
      
      echo "Access revoked on "${serfwan_port}" tcp 0.0.0.0/0."
   else
      echo "WARN: access already revoked ${serfwan_port} udp 0.0.0.0/0."
   fi

   get_application_rpcport 'consul'
   rpc_port="${__RESULT}"
   check_access_is_granted "${sgp_id}" "${rpc_port}" 'tcp' '0.0.0.0/0'
   is_granted="${__RESULT}"

   if [[ 'true' == "${is_granted}" ]]
   then
      revoke_access_from_cidr "${sgp_id}" "${rpc_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
      
      echo "Access revoked on "${rpc_port}" tcp 0.0.0.0/0."
   else
      echo "WARN: access already revoked ${rpc_port} tcp 0.0.0.0/0."
   fi

   get_application_httpport 'consul'
   http_port="${__RESULT}"
   check_access_is_granted "${sgp_id}" "${http_port}" 'tcp' '0.0.0.0/0'
   is_granted="${__RESULT}"

   if [[ 'true' == "${is_granted}" ]]
   then
      revoke_access_from_cidr "${sgp_id}" "${http_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
      
      echo "Access revoked on "${http_port}" tcp 0.0.0.0/0."
   else
      echo "WARN: access already revoked ${http_port} tcp 0.0.0.0/0."
   fi

   get_application_dnsport 'consul'
   dns_port="${__RESULT}"
   check_access_is_granted "${sgp_id}" "${dns_port}" 'tcp' '0.0.0.0/0'
   is_granted="${__RESULT}"

   if [[ 'true' == "${is_granted}" ]]
   then
      revoke_access_from_cidr "${sgp_id}" "${dns_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
      
      echo "Access revoked on "${dns_port}" tcp 0.0.0.0/0."
   else
      echo "WARN: access already revoked ${dns_port} tcp 0.0.0.0/0."
   fi

   check_access_is_granted "${sgp_id}" "${dns_port}" 'udp' '0.0.0.0/0'
   is_granted="${__RESULT}"

   if [[ 'true' == "${is_granted}" ]]
   then
      revoke_access_from_cidr "${sgp_id}" "${dns_port}" 'udp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
      
      echo "Access revoked on "${dns_port}" tcp 0.0.0.0/0."
   else
      echo "WARN: access already revoked ${dns_port} udp 0.0.0.0/0."
   fi   

   echo "Provisioning ${instance_key} instance ..."
 
   get_keypair_name "${instance_key}"
   keypair_nm="${__RESULT}" 
   private_key_file="${ACCESS_DIR}"/"${keypair_nm}" 
   wait_ssh_started "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}"

   ssh_run_remote_command "rm -rf ${SCRIPTS_DIR:?} && mkdir -p ${SCRIPTS_DIR}/consul" \
       "${private_key_file}" \
       "${eip}" \
       "${ssh_port}" \
       "${user_nm}"  
    
   # Prepare the scripts to run on the server.
   get_region_name
   region_nm="${__RESULT}"
   get_application_security_key_name 'consul'
   consul_key_nm="${__RESULT}"
   get_consul_mode "${instance_key}"
   consul_mode="${__RESULT}"
   consul_is_server='false'

   if [[ 'server' == "${consul_mode}" ]]
   then
      consul_is_server='true'
   fi

   sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}/consul")/g" \
       -e "s/SEDdtc_regionSED/${region_nm}/g" \
       -e "s/SEDconsul_service_file_nmSED/consul.service/g" \
       -e "s/SEDconsul_secret_nmSED/${consul_key_nm}/g" \
       -e "s/SEDconsul_is_serverSED/${consul_is_server}/g" \
          "${PROVISION_DIR}"/consul/consul-remove.sh > "${tmp_dir}"/consul-remove.sh  

   echo 'consul-remove.sh ready.' 

   scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${SCRIPTS_DIR}"/consul \
       "${LIBRARY_DIR}"/general_utils.sh \
       "${LIBRARY_DIR}"/secretsmanager.sh \
       "${tmp_dir}"/consul-remove.sh 
         
   echo 'Consul scripts provisioned.'
   
   ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR}"/consul \
       "${private_key_file}" \
       "${eip}" \
       "${ssh_port}" \
       "${user_nm}" \
       "${user_pwd}"  

   # shellcheck disable=SC2015
   ssh_run_remote_command_as_root "${SCRIPTS_DIR}"/consul/consul-remove.sh \
       "${private_key_file}" \
       "${eip}" \
       "${ssh_port}" \
       "${user_nm}" \
       "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Consul successfully removed.' ||
       { 
          echo 'ERROR: removing Consul.'
          exit 1
       }
    
   ssh_run_remote_command "rm -rf ${SCRIPTS_DIR:?}" \
       "${private_key_file}" \
       "${eip}" \
       "${ssh_port}" \
       "${user_nm}"     

   #
   # Firewall.
   #
   
   check_access_is_granted "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0'
   is_granted="${__RESULT}"

   if [[ 'true' == "${is_granted}" ]]
   then
      revoke_access_from_cidr "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
      
      echo "Access revoked on "${ssh_port}" tcp 0.0.0.0/0."
   else
      echo "WARN: access already revoked ${ssh_port} tcp 0.0.0.0/0."
   fi

   #
   # Permissions.
   #

   check_role_has_permission_policy_attached "${role_nm}" "${SECRETSMANAGER_POLICY_NM}"
   is_permission_policy_associated="${__RESULT}"

   if [[ 'true' == "${is_permission_policy_associated}" ]]
   then
      echo "Detaching permission policy from ${instance_key} role ..."

      detach_permission_policy_from_role "${role_nm}" "${SECRETSMANAGER_POLICY_NM}"
      
      echo "Permission policy detached from ${instance_key} role."
   else
      echo "WARN: permission policy already detached from ${instance_key} role."
   fi     

   ## Clearing
   rm -rf "${tmp_dir:?}"
fi

echo
