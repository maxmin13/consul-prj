#!/bin/bash

# shellcheck disable=SC2015

##########################################################################################################
# The script removes Consul from the instance.
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
ssh_key='ssh-application'
consul_key='consul-application'
dummy_key='dummy0-network'
logfile_nm="${instance_key}".log

####
STEP "${instance_key} box Consul remove."
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

# Get the public IP address assigned to the instance. 
ec2_get_public_ip_address_associated_with_instance "${instance_nm}"
eip="${__RESULT}"

if [[ -z "${eip}" ]]
then
   echo '* WARN: IP address not found.'
else
   echo "* IP address: ${eip}."
fi

get_datacenter_instance "${instance_key}" 'SgpName'
sgp_nm="${__RESULT}"
ec2_get_security_group_id "${sgp_nm}"
sgp_id="${__RESULT}"

if [[ -z "${sgp_id}" ]]
then
   echo '* WARN: security group not found.'
else
   echo "* security group ID: ${sgp_id}."
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

get_datacenter_application_port "${instance_key}" "${consul_key}" 'SerfLanPort'
serflan_port="${__RESULT}"
ec2_check_access_is_granted "${sgp_id}" "${serflan_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'true' == "${is_granted}" ]]
then
   ec2_revoke_access_from_cidr "${sgp_id}" "${serflan_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"

   echo "Access revoked on ${serflan_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already revoked ${serflan_port} tcp 0.0.0.0/0."
fi

ec2_check_access_is_granted "${sgp_id}" "${serflan_port}" 'udp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'true' == "${is_granted}" ]]
then
   ec2_revoke_access_from_cidr "${sgp_id}" "${serflan_port}" 'udp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access revoked on ${serflan_port} udp 0.0.0.0/0."
else
   echo "WARN: access already revoked ${serflan_port} udp 0.0.0.0/0."
fi

get_datacenter_application_port "${instance_key}" "${consul_key}" 'SerfWanPort'
serfwan_port="${__RESULT}"
ec2_check_access_is_granted "${sgp_id}" "${serfwan_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'true' == "${is_granted}" ]]
then
   ec2_revoke_access_from_cidr "${sgp_id}" "${serfwan_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"

   echo "Access revoked on ${serfwan_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already revoked ${serfwan_port} tcp 0.0.0.0/0."
fi

ec2_check_access_is_granted "${sgp_id}" "${serfwan_port}" 'udp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'true' == "${is_granted}" ]]
then
   ec2_revoke_access_from_cidr "${sgp_id}" "${serfwan_port}" 'udp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"

   echo "Access revoked on ${serfwan_port} udp 0.0.0.0/0."
else
   echo "WARN: access already revoked ${serfwan_port} udp 0.0.0.0/0."
fi

get_datacenter_application_port "${instance_key}" "${consul_key}" 'RpcPort'
rpc_port="${__RESULT}"
ec2_check_access_is_granted "${sgp_id}" "${rpc_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'true' == "${is_granted}" ]]
then
   ec2_revoke_access_from_cidr "${sgp_id}" "${rpc_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"

   echo "Access revoked on ${rpc_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already revoked ${rpc_port} tcp 0.0.0.0/0."
fi

get_datacenter_application_port "${instance_key}" "${consul_key}" 'HttpPort'
http_port="${__RESULT}"
ec2_check_access_is_granted "${sgp_id}" "${http_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'true' == "${is_granted}" ]]
then
   ec2_revoke_access_from_cidr "${sgp_id}" "${http_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"

   echo "Access revoked on ${http_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already revoked ${http_port} tcp 0.0.0.0/0."
fi

get_datacenter_application_port "${instance_key}" "${consul_key}" 'DnsPort'
dns_port="${__RESULT}"
ec2_check_access_is_granted "${sgp_id}" "${dns_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'true' == "${is_granted}" ]]
then
   ec2_revoke_access_from_cidr "${sgp_id}" "${dns_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"

   echo "Access revoked on ${dns_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already revoked ${dns_port} tcp 0.0.0.0/0."
fi

ec2_check_access_is_granted "${sgp_id}" "${dns_port}" 'udp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'true' == "${is_granted}" ]]
then
   ec2_revoke_access_from_cidr "${sgp_id}" "${dns_port}" 'udp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"

   echo "Access revoked on ${dns_port} udp 0.0.0.0/0."
else
   echo "WARN: access already revoked ${dns_port} udp 0.0.0.0/0."
fi   

echo "Provisioning ${instance_key} instance ..."
 
get_datacenter_instance "${instance_key}" 'UserName'
user_nm="${__RESULT}"
get_datacenter_instance "${instance_key}" 'KeypairName'
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

sed -e "s/SEDlibrary_dirSED/$(escape "${remote_dir}"/consul)/g" \
    -e "s/SEDinstance_keySED/${instance_key}/g" \
    -e "s/SEDconsul_keySED/${consul_key}/g" \
    -e "s/SEDdummy_keySED/${dummy_key}/g" \
    "${PROVISION_DIR}"/consul/consul-remove.sh > "${temporary_dir}"/consul-remove.sh  

echo 'consul-remove.sh ready.' 

scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/consul \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/service_consts_utils.sh \
    "${LIBRARY_DIR}"/datacenter_consts_utils.sh \
    "${PROVISION_DIR}"/dns/dhclient.conf \
    "${LIBRARY_DIR}"/consul.sh \
    "${LIBRARY_DIR}"/network.sh \
    "${LIBRARY_DIR}"/secretsmanager.sh \
    "${temporary_dir}"/consul-remove.sh
    
scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/consul/constants \
    "${LIBRARY_DIR}"/constants/datacenter_consts.json \
    "${LIBRARY_DIR}"/constants/service_consts.json        
   
echo 'Consul scripts provisioned.'

get_datacenter_instance "${instance_key}" "UserPassword"
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
   ssh_run_remote_command_as_root "${remote_dir}"/consul/consul-remove.sh \
       "${private_key_file}" \
       "${eip}" \
       "${ssh_port}" \
       "${user_nm}" \
       "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" ||
       {     
          exit_code=$?
          
          if [[ 194 -eq "${exit_code}" ]]
          then
             echo 'Consul successfully removed.'
          
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
                   
             break 2 ## exit the loop
          else
             if [[ 1 -eq "${i}" ]]
             then
                echo 'WARN: changes made to IAM entities can take noticeable time for the information to be reflected globally.'
                echo 'Let''s wait a bit and check again.'             
             
                wait 30
             else
                break 2
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
   echo 'Detaching secretsmangers permission policy from role ...'
 
   iam_detach_permission_policy_from_role "${role_nm}" "${SECRETSMANAGER_POLICY_NM}"
      
   echo 'Secretsmangers permission policy detached from role.'
else
   echo 'WARN: secretsmangers permission policy already detached from role.'
fi  

#
# Firewall.
#

ec2_check_access_is_granted "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'true' == "${is_granted}" ]]
then
   ec2_revoke_access_from_cidr "${sgp_id}" "${ssh_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"

   echo "Access revoked on ${ssh_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already revoked ${ssh_port} tcp 0.0.0.0/0."
fi

## Clearing
rm -rf "${temporary_dir:?}"

echo
