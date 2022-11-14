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
dummy_key='dummy0-network'
ssh_key='ssh-application'
admin_instance_key='admin-instance'
consul_key='consul-application'
nginx_key='nginx-application'
dnsmasq_key='dnsmasq-application'
registrator_key='registrator-application'
logfile_nm="${instance_key}".log

####
STEP "${instance_key} box Consul provision."
####

get_datacenter_instance "${instance_key}" 'Name'
instance_nm="${__RESULT}"
ec2_instance_is_running "${instance_nm}"
is_running="${__RESULT}"
ec2_get_instance_state "${instance_nm}"
instance_st="${__RESULT}"

if [[ 'true' == "${is_running}" ]]
then
   echo "* ${instance_key} box ready (${instance_st})."
else
   if [[ -n "${instance_st}" ]]
   then
      echo "* WARN: ${instance_key} box is not ready (${instance_st})."
   else
      echo "* WARN: ${instance_key} box is not ready."
   fi
      
   return 0
fi

ec2_get_public_ip_address_associated_with_instance "${instance_nm}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo "* ERROR:  ${instance_key} IP address not found."
   exit 1
else
   echo "* ${instance_key} IP address: ${eip}."
fi

get_datacenter_instance "${instance_key}" 'SgpName'
sgp_nm="${__RESULT}"
ec2_get_security_group_id "${sgp_nm}"
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

get_datacenter_instance "${instance_key}" 'RoleName'
role_nm="${__RESULT}" 

iam_check_role_has_permission_policy_attached "${role_nm}" "${SECRETSMANAGER_POLICY_NM}"
is_sm_policy_associated="${__RESULT}"

if [[ 'false' == "${is_sm_policy_associated}" ]]
then
   echo 'Associating SM permission policy to role ...'

   iam_attach_permission_policy_to_role "${role_nm}" "${SECRETSMANAGER_POLICY_NM}"

   echo 'SM permission policy associated to role.'
else
   echo 'WARN: SM permission policy already associated to role.'
fi   
	
#
# Firewall rules
#

get_datacenter_application "${instance_key}" "${ssh_key}" 'Port'
ssh_port="${__RESULT}"
ec2_check_access_is_granted "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   ec2_allow_access_from_cidr "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access granted on ${ssh_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${ssh_port} tcp 0.0.0.0/0."
fi

echo 'Provisioning instance ...'

get_datacenter_instance "${instance_key}" 'UserName'
user_nm="${__RESULT}"
get_datacenter_instance "${instance_key}" 'KeypairName'
keypair_nm="${__RESULT}" 
private_key_file="${ACCESS_DIR}"/"${keypair_nm}" 
wait_ssh_started "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}"
remote_dir=/home/"${user_nm}"/script

ssh_run_remote_command "rm -rf ${remote_dir:?} && mkdir -p ${remote_dir}/consul" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"  
     
#    
# Prepare the scripts to run on the server.
#

echo

get_datacenter_instance_admin 'Name'
admin_nm="${__RESULT}"
ec2_get_public_ip_address_associated_with_instance "${admin_nm}"
admin_eip="${__RESULT}"

sed -e "s/SEDremote_dirSED/$(escape "${remote_dir}"/consul)/g" \
    -e "s/SEDlibrary_dirSED/$(escape "${remote_dir}"/consul)/g" \
    -e "s/SEDconstants_dirSED/$(escape "${remote_dir}"/consul)/g" \
    -e "s/SEDinstance_keySED/${instance_key}/g" \
    -e "s/SEDnginx_keySED/${nginx_key}/g" \
    -e "s/SEDconsul_keySED/${consul_key}/g" \
    -e "s/SEDdnsmasq_keySED/${dnsmasq_key}/g" \
    -e "s/SEDregistrator_keySED/${registrator_key}/g" \
    -e "s/SEDdummy_keySED/${dummy_key}/g" \
    -e "s/SEDadmin_eipSED/${admin_eip}/g" \
    -e "s/SEDadmin_instance_keySED/${admin_instance_key}/g" \
       "${PROVISION_DIR}"/consul/consul-install.sh > "${temporary_dir}"/consul-install.sh  
       
echo 'consul-install.sh ready.'

get_datacenter_application "${instance_key}" "${consul_key}" 'Mode'
consul_mode="${__RESULT}"  

if [[ 'server' == "${consul_mode}" ]]
then
   cp "${PROVISION_DIR}"/consul/consul-server.json "${temporary_dir}"/consul-config.json
else
   cp "${PROVISION_DIR}"/consul/consul-client.json "${temporary_dir}"/consul-config.json
fi  

echo 'consul.json ready.'

scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/consul \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/service_consts_utils.sh \
    "${LIBRARY_DIR}"/datacenter_consts_utils.sh \
    "${LIBRARY_DIR}"/secretsmanager.sh \
    "${LIBRARY_DIR}"/consul.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/network.sh \
    "${PROVISION_DIR}"/dnsmasq/dnsmasq.conf \
    "${PROVISION_DIR}"/dns/dhclient.conf \
    "${PROVISION_DIR}"/network/dummy/ifcfg-dummy \
    "${PROVISION_DIR}"/network/dummy/dummymodule.conf \
    "${PROVISION_DIR}"/nginx/nginx-reverse-proxy.conf \
    "${temporary_dir}"/consul-config.json \
    "${PROVISION_DIR}"/consul/consul-systemd.service \
    "${temporary_dir}"/consul-install.sh \
    "${CONSTANTS_DIR}"/datacenter_consts.json \
    "${CONSTANTS_DIR}"/service_consts.json 
        
echo 'Consul scripts provisioned.'
echo 'Installing Consul ...'

get_datacenter_instance "${instance_key}" 'UserPassword'
user_pwd="${__RESULT}"

ssh_run_remote_command_as_root "chmod -R +x ${remote_dir}/consul" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}"   

i=0
set +e
for i in {1,2}
do
   ssh_run_remote_command_as_root "${remote_dir}"/consul/consul-install.sh \
       "${private_key_file}" \
       "${eip}" \
       "${ssh_port}" \
       "${user_nm}" \
       "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" ||
       {     
          exit_code=$?
          
          if [[ 194 -eq "${exit_code}" ]]
          then
             echo 'Consul successfully installed.'
          
             ssh_run_remote_command "rm -rf ${remote_dir}" \
                "${private_key_file}" \
                "${eip}" \
                "${ssh_port}" \
                "${user_nm}" \
                "${user_pwd}"          
             
             echo 'Rebooting the instance ...'
              
             ssh_run_remote_command_as_root "reboot" \
                "${private_key_file}" \
                "${eip}" \
                "${ssh_port}" \
                "${user_nm}" \
                "${user_pwd}"
                   
             break ## exit the loop
          else
             if [[ 1 -eq "${i}" ]] # if first loop
             then
                echo 'WARN: changes made to IAM entities can take noticeable time for the information to be reflected globally.'
                echo 'Let''s wait a bit and check again.'             
             
                wait 30
             else
                echo 'ERROR: installing Consul'
                exit 1
             fi
          fi
       }
done  
set -e   
      
#
# Permissions.
#

iam_check_role_has_permission_policy_attached "${role_nm}" "${SECRETSMANAGER_POLICY_NM}"
is_sm_policy_associated="${__RESULT}"

if [[ 'true' == "${is_sm_policy_associated}" ]]
then
   echo 'Detaching secretsmanger permission policy from role ...'
 
   iam_detach_permission_policy_from_role "${role_nm}" "${SECRETSMANAGER_POLICY_NM}"
      
   echo 'Secretsmangers permission policy detached from role.'
else
   echo 'WARN: secretsmanger permission policy already detached from role.'
fi

## 
## Firewall.
##

ec2_check_access_is_granted "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'true' == "${is_granted}" ]]
then
   ec2_revoke_access_from_cidr "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access revoked on ${ssh_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already revoked ${ssh_port} tcp 0.0.0.0/0."
fi 

get_datacenter_application_port "${instance_key}" "${consul_key}" 'SerfLanPort'
serflan_port="${__RESULT}"
ec2_check_access_is_granted "${sgp_id}" "${serflan_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   ec2_allow_access_from_cidr "${sgp_id}" "${serflan_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access granted on ${serflan_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${serflan_port} tcp 0.0.0.0/0."
fi

ec2_check_access_is_granted "${sgp_id}" "${serflan_port}" 'udp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   ec2_allow_access_from_cidr "${sgp_id}" "${serflan_port}" 'udp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access granted on ${serflan_port} udp 0.0.0.0/0."
else
   echo "WARN: access already granted ${serflan_port} udp 0.0.0.0/0."
fi

get_datacenter_application_port "${instance_key}" "${consul_key}" 'SerfWanPort'
serfwan_port="${__RESULT}"
ec2_check_access_is_granted "${sgp_id}" "${serfwan_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   ec2_allow_access_from_cidr "${sgp_id}" "${serfwan_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access granted on ${serfwan_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${serfwan_port} tcp 0.0.0.0/0."
fi

ec2_check_access_is_granted "${sgp_id}" "${serfwan_port}" 'udp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   ec2_allow_access_from_cidr "${sgp_id}" "${serfwan_port}" 'udp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access granted on ${serfwan_port} udp 0.0.0.0/0."
else
   echo "WARN: access already granted ${serfwan_port} udp 0.0.0.0/0."
fi

get_datacenter_application_port "${instance_key}" "${consul_key}" 'RpcPort'
rpc_port="${__RESULT}"
ec2_check_access_is_granted "${sgp_id}" "${rpc_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   ec2_allow_access_from_cidr "${sgp_id}" "${rpc_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access granted on ${rpc_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${rpc_port} tcp 0.0.0.0/0."
fi

get_datacenter_application_port "${instance_key}" "${consul_key}" 'HttpPort'
http_port="${__RESULT}"
ec2_check_access_is_granted "${sgp_id}" "${http_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   ec2_allow_access_from_cidr "${sgp_id}" "${http_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access granted on ${http_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${http_port} tcp 0.0.0.0/0."
fi

get_datacenter_application_port "${instance_key}" "${consul_key}" 'DnsPort'
dns_port="${__RESULT}"
ec2_check_access_is_granted "${sgp_id}" "${dns_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   ec2_allow_access_from_cidr "${sgp_id}" "${dns_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access granted on ${dns_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${dns_port} tcp 0.0.0.0/0."
fi

ec2_check_access_is_granted "${sgp_id}" "${dns_port}" 'udp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   ec2_allow_access_from_cidr "${sgp_id}" "${dns_port}" 'udp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access granted on ${dns_port} udp 0.0.0.0/0."
else
   echo "WARN: access already granted ${dns_port} udp 0.0.0.0/0."
fi
 
if [[ 'server' == "${consul_mode}" ]]
then
   # Consul ui is exposed through Nginx reverse proxy.
   get_datacenter_application_port "${instance_key}" "${nginx_key}" 'ProxyPort'
   nginx_port="${__RESULT}"
   ec2_check_access_is_granted "${sgp_id}" "${nginx_port}" 'tcp' '0.0.0.0/0'
   is_granted="${__RESULT}"

   if [[ 'false' == "${is_granted}" ]]
   then
      ec2_allow_access_from_cidr "${sgp_id}" "${nginx_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
      echo "Access granted on ${nginx_port} tcp 0.0.0.0/0."
   else
      echo "WARN: access already granted ${nginx_port} tcp 0.0.0.0/0."
   fi 
fi 
 
# Removing old files
# shellcheck disable=SC2115
rm -rf  "${temporary_dir:?}" 

get_datacenter_application_port "${admin_instance_key}" "${nginx_key}" 'ProxyPort'
proxy_port="${__RESULT}"
get_datacenter_application_url "${admin_instance_key}" "${consul_key}" "${admin_eip}" "${proxy_port}"
application_url="${__RESULT}" 

echo "${application_url}" 
echo  

