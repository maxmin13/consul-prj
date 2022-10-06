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
STEP "${instance_key} box Consul provision."
####

get_instance "${instance_key}" 'Name'
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

get_public_ip_address_associated_with_instance "${instance_nm}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo "* ERROR:  ${instance_key} IP address not found."
   exit 1
else
   echo "* ${instance_key} IP address: ${eip}."
fi

get_instance "${instance_key}" 'SgpName'
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

get_instance "${instance_key}" 'RoleName'
role_nm="${__RESULT}" 

check_role_has_permission_policy_attached "${role_nm}" "${SECRETSMANAGER_POLICY_NM}"
is_permission_policy_associated="${__RESULT}"

if [[ 'false' == "${is_permission_policy_associated}" ]]
then
   echo 'Associating permission policy to role ...'

   attach_permission_policy_to_role "${role_nm}" "${SECRETSMANAGER_POLICY_NM}"

   echo 'Permission policy associated to role.'
else
   echo 'Permission policy already associated to role.'
fi 

#
# Firewall rules
#

get_application "${instance_key}" 'ssh' 'Port'
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

get_application_port "${instance_key}" 'consul' 'SerfLanPort'
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
   
   echo "Access granted on ${serflan_port} udp 0.0.0.0/0."
else
   echo "WARN: access already granted ${serflan_port} udp 0.0.0.0/0."
fi

get_application_port "${instance_key}" 'consul' 'SerfWanPort'
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
   
   echo "Access granted on ${serfwan_port} udp 0.0.0.0/0."
else
   echo "WARN: access already granted ${serfwan_port} udp 0.0.0.0/0."
fi

get_application_port "${instance_key}" 'consul' 'RpcPort'
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

get_application_port "${instance_key}" 'consul' 'HttpPort'
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

get_application_port "${instance_key}" 'consul' 'DnsPort'
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
   
   echo "Access granted on ${dns_port} udp 0.0.0.0/0."
else
   echo "WARN: access already granted ${dns_port} udp 0.0.0.0/0."
fi

echo 'Provisioning instance ...'

get_instance "${instance_key}" 'UserName'
user_nm="${__RESULT}"
get_instance "${instance_key}" 'KeypairName'
keypair_nm="${__RESULT}" 
private_key_file="${ACCESS_DIR}"/"${keypair_nm}" 
wait_ssh_started "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}"
remote_dir=/home/"${user_nm}"/script

ssh_run_remote_command "rm -rf ${remote_dir:?} && mkdir -p ${remote_dir}/consul/constants" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"  
     
#    
# Prepare the scripts to run on the server.
#

echo

get_instance 'admin' 'Name'
admin_nm="${__RESULT}"
get_public_ip_address_associated_with_instance "${admin_nm}"
admin_eip="${__RESULT}"

sed -e "s/SEDremote_dirSED/$(escape "${remote_dir}"/consul)/g" \
    -e "s/SEDlibrary_dirSED/$(escape "${remote_dir}"/consul)/g" \
    -e "s/SEDinstance_keySED/${instance_key}/g" \
    -e "s/SEDadmin_eipSED/${admin_eip}/g" \
       "${PROVISION_DIR}"/consul/consul-install.sh > "${temporary_dir}"/consul-install.sh  
       
echo 'consul-install.sh ready.'

get_application "${instance_key}" 'consul' 'Mode'
consul_mode="${__RESULT}"  
get_instance "${instance_key}" 'PrivateIP'
private_ip="${__RESULT}"

if [[ 'server' == "${consul_mode}" ]]
then
   sed -e "s/SEDbind_addressSED/${private_ip}/g" \
       -e "s/SEDbootstrap_expectSED/1/g" \
       "${PROVISION_DIR}"/consul/consul-server.json > "${temporary_dir}"/consul.json
else
   # The admin box runs the Consul server, each Consul client binds to it at start-up.
   get_instance 'admin' 'PrivateIP'
   bind_ip="${__RESULT}"
   
   sed -e "s/SEDbind_addressSED/${private_ip}/g" \
       -e "s/SEDbootstrap_expectSED/1/g" \
       -e "s/SEDstart_join_bind_addressSED/${bind_ip}/g" \
       "${PROVISION_DIR}"/consul/consul-client.json > "${temporary_dir}"/consul.json
fi  

echo 'consul.json ready.'

scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/consul \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/service_consts_utils.sh \
    "${LIBRARY_DIR}"/datacenter_consts_utils.sh \
    "${LIBRARY_DIR}"/secretsmanager.sh \
    "${LIBRARY_DIR}"/consul.sh \
    "${temporary_dir}"/consul.json \
    "${temporary_dir}"/consul-install.sh \
    "${PROVISION_DIR}"/consul/systemd.service
    
scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/consul/constants \
    "${LIBRARY_DIR}"/constants/datacenter_consts.json \
    "${LIBRARY_DIR}"/constants/service_consts.json         
         
echo 'Consul scripts provisioned.'
echo 'Installing Consul '

get_instance "${instance_key}" 'UserPassword'
user_pwd="${__RESULT}"

ssh_run_remote_command_as_root "chmod -R +x ${remote_dir}/consul" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}"      

ssh_run_remote_command_as_root "${remote_dir}"/consul/consul-install.sh \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Consul successfully installed.' ||
    {    
       echo 'WARN: changes made to IAM entities can take noticeable time for the information to be reflected globally.'
       echo 'Let''s wait a bit and check again.' 
      
       wait 60  
      
       echo 'Let''s try now.' 
    
       ssh_run_remote_command_as_root "${remote_dir}"/consul/consul-install.sh \
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
 
get_instance 'admin' 'Name'
admin_nm="${__RESULT}"
get_public_ip_address_associated_with_instance "${admin_nm}"
admin_eip="${__RESULT}"

echo "http://${admin_eip}:${http_port}/ui"  
    
#
# Permissions.
#

check_role_has_permission_policy_attached "${role_nm}" "${SECRETSMANAGER_POLICY_NM}"
is_permission_policy_associated="${__RESULT}"

if [[ 'true' == "${is_permission_policy_associated}" ]]
then
   echo 'Detaching permission policy from role ...'
 
   detach_permission_policy_from_role "${role_nm}" "${SECRETSMANAGER_POLICY_NM}"
      
   echo 'Permission policy detached from role.'
else
   echo 'WARN: permission policy already detached from role.'
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
 
echo  

