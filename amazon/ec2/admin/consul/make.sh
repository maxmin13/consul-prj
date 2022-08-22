#!/bin/bash

# shellcheck disable=SC2015

##########################################################################################################
#
# Consul is a datacenter runtime that provides service discovery, configuration, and orchestration.
# The script installs Consul in the Admin instance and runs a cluster with one server.
# 
##########################################################################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR=/home/"${USER_NM}"/script

####
STEP 'Admin Consul'
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
   echo '* ERROR: Admin instance not found.'
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

get_security_group_id "${ADMIN_INST_SEC_GRP_NM}"
admin_sgp_id="${__RESULT}"

if [[ -z "${admin_sgp_id}" ]]
then
   echo '* ERROR: Admin security group not found.'
   exit 1
else
   echo "* Admin security group ID: ${admin_sgp_id}."
fi


# Get the public IP address assigned to the instance. 
get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}"
admin_eip="${__RESULT}"

if [[ -z "${admin_eip}" ]]
then
   echo '* ERROR: Admin public IP address not found.'
   exit 1
else
   echo "* Admin public IP address: ${admin_eip}."
fi

# Removing old files
# shellcheck disable=SC2115
admin_tmp_dir="${TMP_DIR}"/consul
rm -rf  "${admin_tmp_dir:?}"
mkdir -p "${admin_tmp_dir}"

echo

#
# Firewall rules
#

set +e
# Firewall rules 
allow_access_from_cidr "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
allow_access_from_cidr "${admin_sgp_id}" "${ADMIN_CONSUL_SERVER_SERF_LAN_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
allow_access_from_cidr "${admin_sgp_id}" "${ADMIN_CONSUL_SERVER_SERF_LAN_PORT}" 'udp' '0.0.0.0/0' > /dev/null 2>&1
allow_access_from_cidr "${admin_sgp_id}" "${ADMIN_CONSUL_SERVER_SERF_WAN_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
allow_access_from_cidr "${admin_sgp_id}" "${ADMIN_CONSUL_SERVER_SERF_WAN_PORT}" 'udp' '0.0.0.0/0' > /dev/null 2>&1
allow_access_from_cidr "${admin_sgp_id}" "${ADMIN_CONSUL_SERVER_RPC_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
allow_access_from_cidr "${admin_sgp_id}" "${ADMIN_CONSUL_SERVER_HTTP_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
allow_access_from_cidr "${admin_sgp_id}" "${ADMIN_CONSUL_SERVER_DNS_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
allow_access_from_cidr "${admin_sgp_id}" "${ADMIN_CONSUL_SERVER_DNS_PORT}" 'udp' '0.0.0.0/0' > /dev/null 2>&1
set -e
   
echo 'Granted access to the Admin box.'

#
echo 'Provisioning the Admin instance ...'
# 

private_key_file="${ACCESS_DIR}"/"${ADMIN_INST_KEY_PAIR_NM}" 
wait_ssh_started "${private_key_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}"

ssh_run_remote_command "rm -rf ${SCRIPTS_DIR} && mkdir -p ${SCRIPTS_DIR}" \
    "${private_key_file}" \
    "${admin_eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}"  
    
# Prepare the scripts to run on the server.

echo 'Provisioning Consul scripts ...'

sed -e "s/SEDscripts_dirSED/$(escape "${SCRIPTS_DIR}")/g" \
    -e "s/SEDinstance_eip_addressSED/${admin_eip}/g" \
    -e "s/SEDinstance_private_addressSED/${ADMIN_INST_PRIVATE_IP}/g" \
    -e "s/SEDconsul_config_file_nmSED/consul-server.json/g" \
    -e "s/SEDconsul_service_file_nmSED/consul.service/g" \
    -e "s/SEDconsul_http_portSED/${ADMIN_CONSUL_SERVER_HTTP_PORT}/g" \
    -e "s/SEDconsul_dns_portSED/${ADMIN_CONSUL_SERVER_DNS_PORT}/g" \
       "${SERVICES_DIR}"/consul/consul.sh > "${admin_tmp_dir}"/consul.sh  
     
echo 'consul.sh ready.'   

sed -e "s/SEDbind_addressSED/${ADMIN_INST_PRIVATE_IP}/g" \
    -e "s/SEDbootstrap_expectSED/1/g" \
    "${SERVICES_DIR}"/consul/consul-server.json > "${admin_tmp_dir}"/consul-server.json
    
echo 'consul-server.json ready.'      
      
scp_upload_files "${private_key_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}" \
    "${admin_tmp_dir}"/consul.sh \
    "${admin_tmp_dir}"/consul-server.json \
    "${SERVICES_DIR}"/consul/consul.service \
    "${LIBRARY_DIR}"/general_utils.sh 
         
echo 'Consul scripts provisioned.'
echo

ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR}" \
    "${private_key_file}" \
    "${admin_eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}"      

ssh_run_remote_command_as_root "${SCRIPTS_DIR}/consul.sh" \
    "${private_key_file}" \
    "${admin_eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}" \
    "${USER_PWD}" && echo 'Consul successfully installed.'
    
ssh_run_remote_command "rm -rf ${SCRIPTS_DIR}" \
    "${private_key_file}" \
    "${admin_eip}" \
    "${SHARED_INST_SSH_PORT}" \
    "${USER_NM}"      

## 
## SSH Access.
##

set +e
  revoke_access_from_cidr "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
set -e

echo 'Revoked SSH access to the Admin box.'  

# Removing old files
# shellcheck disable=SC2115
rm -rf  "${admin_tmp_dir:?}"


