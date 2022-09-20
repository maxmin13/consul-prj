#!/bin/bash

# shellcheck disable=SC2015

##########################################################################################################
# Consul is a datacenter runtime that provides service discovery, configuration, and orchestration.
# The script installs Consul in the Admin instance, as a server or client, depending on the ConsulMode 
# set in the ec2_consts.json configuration file.
# The cluster is composed by a Consul server that runs in the Admin instance and a Consul client installed
# in every host in the network.
##########################################################################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

# Enforce parameter
if [ "$#" -lt 1 ]; then
  echo "USAGE: instance_key"
  echo "EXAMPLE: admin"
  echo "Only provided $# arguments"
  exit 1
fi

instance_key="${1}"
logfile_nm="${instance_key}".log

####
STEP "${instance_key} box Consul"
####

get_instance_name "${instance_key}"
instance_nm="${__RESULT}"
instance_is_running "${instance_nm}"
is_running="${__RESULT}"
get_instance_state "${instance_nm}"
instance_st="${__RESULT}"

if [[ 'true' == "${is_running}" ]]
then
   echo "* ${instance_key} box ready (${instance_st})."
else
   echo "* WARN: ${instance_key} box is not ready (${instance_st})."
      
   return 0
fi

# Get the public IP address assigned to the instance. 
get_public_ip_address_associated_with_instance "${instance_nm}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo "* ERROR:  ${instance_key} IP address not found."
   exit 1
else
   echo "* ${instance_key} IP address: ${eip}."
fi

get_security_group_name "${instance_key}"
sgp_nm="${__RESULT}"
get_security_group_id "${sgp_nm}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo "* ERROR: ${instance_key} security group not found."
   exit 1
else
   echo "* ${instance_key} security group ID: ${sgp_id}."
fi

# Removing old files
# shellcheck disable=SC2153
temporary_dir="${TMP_DIR}"/${instance_key}/consul
rm -rf  "${temporary_dir:?}"
mkdir -p "${temporary_dir}"

echo

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
   
   echo "Access granted on ${ssh_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${ssh_port} tcp 0.0.0.0/0."
fi

get_application_serflanport 'consul'
serflan_port="${__RESULT}"
check_access_is_granted "${sgp_id}" "${serflan_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${serflan_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access granted on ${serflan_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${serflan_port} tcp 0.0.0.0/0."
fi

check_access_is_granted "${sgp_id}" "${serflan_port}" 'udp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${serflan_port}" 'udp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access granted on ${serflan_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${serflan_port} udp 0.0.0.0/0."
fi

get_application_serfwanport 'consul'
serfwan_port="${__RESULT}"
check_access_is_granted "${sgp_id}" "${serfwan_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${serfwan_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access granted on ${serfwan_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${serfwan_port} tcp 0.0.0.0/0."
fi

check_access_is_granted "${sgp_id}" "${serfwan_port}" 'udp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${serfwan_port}" 'udp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access granted on ${serfwan_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${serfwan_port} udp 0.0.0.0/0."
fi

get_application_rpcport 'consul'
rpc_port="${__RESULT}"
check_access_is_granted "${sgp_id}" "${rpc_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${rpc_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access granted on ${rpc_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${rpc_port} tcp 0.0.0.0/0."
fi

get_application_httpport 'consul'
http_port="${__RESULT}"
check_access_is_granted "${sgp_id}" "${http_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${http_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access granted on ${http_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${http_port} tcp 0.0.0.0/0."
fi

get_application_dnsport 'consul'
dns_port="${__RESULT}"
check_access_is_granted "${sgp_id}" "${dns_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${dns_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access granted on ${dns_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${dns_port} tcp 0.0.0.0/0."
fi

check_access_is_granted "${sgp_id}" "${dns_port}" 'udp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   allow_access_from_cidr "${sgp_id}" "${dns_port}" 'udp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access granted on ${dns_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${dns_port} udp 0.0.0.0/0."
fi

echo "Provisioning ${instance_key} instance ..."

get_keypair_name "${instance_key}"
keypair_nm="${__RESULT}" 
private_key_file="${ACCESS_DIR}"/"${keypair_nm}" 
wait_ssh_started "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}"

get_user_name
user_nm="${__RESULT}"
remote_dir=/home/"${user_nm}"/script

ssh_run_remote_command "rm -rf ${remote_dir:?} && mkdir -p ${remote_dir}/${instance_key}/consul" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"  
    
# Prepare the scripts to run on the server.
get_region_name
region_nm="${__RESULT}"
get_private_ip "${instance_key}"
private_ip="${__RESULT}" 
get_application_security_key_name 'consul'
consul_key_nm="${__RESULT}"
get_consul_mode "${instance_key}"
consul_mode="${__RESULT}"
consul_is_server='false'

if [[ 'server' == "${consul_mode}" ]]
then
   consul_is_server='true'
fi

sed -e "s/SEDscripts_dirSED/$(escape "${remote_dir}"/"${instance_key}"/consul)/g" \
    -e "s/SEDdtc_regionSED/${region_nm}/g" \
    -e "s/SEDinstance_eip_addressSED/${eip}/g" \
    -e "s/SEDinstance_private_addressSED/${private_ip}/g" \
    -e "s/SEDconsul_config_file_nmSED/consul-config.json/g" \
    -e "s/SEDconsul_service_file_nmSED/consul.service/g" \
    -e "s/SEDconsul_http_portSED/${http_port}/g" \
    -e "s/SEDconsul_dns_portSED/${dns_port}/g" \
    -e "s/SEDconsul_is_serverSED/${consul_is_server}/g" \
    -e "s/SEDconsul_secret_nmSED/${consul_key_nm}/g" \
       "${PROVISION_DIR}"/consul/consul-install.sh > "${temporary_dir}"/consul-install.sh  
       
echo 'consul-install.sh ready.'  

if [[ 'true' == "${consul_is_server}" ]]
then
   sed -e "s/SEDbind_addressSED/${private_ip}/g" \
       -e "s/SEDbootstrap_expectSED/1/g" \
       "${PROVISION_DIR}"/consul/consul-server.json > "${temporary_dir}"/consul-config.json
    
   echo 'consul-server.json ready.'
else
   # The admin box runs the Consul server, each Consul client binds to it at start-up.
   get_private_ip 'admin'
   server_bind_ip="${__RESULT}"

   sed -e "s/SEDbind_addressSED/${private_ip}/g" \
       -e "s/SEDbootstrap_expectSED/1/g" \
       -e "s/SEDstart_join_bind_addressSED/${server_bind_ip}/g" \
       "${PROVISION_DIR}"/consul/consul-client.json > "${temporary_dir}"/consul-config.json
       
   echo 'consul-client.json ready.'  
fi  

scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/"${instance_key}"/consul \
    "${temporary_dir}"/consul-install.sh \
    "${temporary_dir}"/consul-config.json \
    "${PROVISION_DIR}"/consul/consul.service \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/secretsmanager.sh 
         
echo 'Consul scripts provisioned.'

if [[ 'true' == "${consul_is_server}" ]]
then
   echo 'Installing Consul in server mode ...'
else
   echo 'Installing Consul in client mode ...'
fi

get_user_password
user_pwd="${__RESULT}"

ssh_run_remote_command_as_root "chmod -R +x ${remote_dir}/${instance_key}/consul" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}"      

ssh_run_remote_command_as_root "${remote_dir}"/"${instance_key}"/consul/consul-install.sh \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Consul successfully installed.' ||
    {    
       echo 'WARN: changes made to IAM entities can take noticeable time for the information to be reflected globally.'
       echo 'Let''s wait a bit and check again (first time).' 
      
       wait 180  
      
       echo 'Let''s try now.' 
    
       ssh_run_remote_command_as_root "${remote_dir}"/"${instance_key}"/consul/consul-install.sh \
          "${private_key_file}" \
          "${eip}" \
          "${ssh_port}" \
          "${user_nm}" \
          "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Consul successfully installed.' ||
          {
              echo 'ERROR: the problem persists after 3 minutes.'
              exit 1          
          }
    }
   
ssh_run_remote_command "rm -rf ${remote_dir:?}" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"      
    
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

## 
## Firewall.
##

check_access_is_granted "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'true' == "${is_granted}" ]]
then
   revoke_access_from_cidr "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access revoked on ${ssh_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already revoked ${ssh_port} tcp 0.0.0.0/0."
fi  

# Removing old files
# shellcheck disable=SC2115
rm -rf  "${temporary_dir:?}"

echo "http://${eip}:${http_port}/ui"  
echo  

