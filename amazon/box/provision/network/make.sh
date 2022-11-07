#!/bin/bash

# shellcheck disable=SC2015

##########################################################################################################
# 
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
swarm_key='swarm-application'
overlaynet_key='sinnet3-network'
logfile_nm="${instance_key}".log

####
STEP "${instance_key} box network provision."
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
   echo "* WARN: ${instance_key} box is not ready (${instance_st})."
      
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
temporary_dir="${TMP_DIR}"/${instance_key}/overlaynet
rm -rf  "${temporary_dir:?}"
mkdir -p "${temporary_dir}"

echo
	
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

ssh_run_remote_command "rm -rf ${remote_dir:?} && mkdir -p ${remote_dir}/overlaynet/constants" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"  
     
#    
# Prepare the scripts to run on the server.
#

echo

sed -e "s/SEDremote_dirSED/$(escape "${remote_dir}"/overlaynet)/g" \
    -e "s/SEDlibrary_dirSED/$(escape "${remote_dir}"/overlaynet)/g" \
    -e "s/SEDinstance_keySED/${instance_key}/g" \
    -e "s/SEDswarm_keySED/${swarm_key}/g" \
    -e "s/SEDoverlaynet_keySED/${overlaynet_key}/g" \
       "${PROVISION_DIR}"/network/overlaynet-install.sh > "${temporary_dir}"/overlaynet-install.sh  
       
echo 'overlaynet-install.sh ready.'

scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/overlaynet \
    "${LIBRARY_DIR}"/general_utils.sh \
    "${LIBRARY_DIR}"/datacenter_consts_utils.sh \
    "${LIBRARY_DIR}"/dockerlib.sh \
    "${LIBRARY_DIR}"/consul.sh \
    "${temporary_dir}"/overlaynet-install.sh
    
scp_upload_files "${private_key_file}" "${eip}" "${ssh_port}" "${user_nm}" "${remote_dir}"/overlaynet/constants \
    "${LIBRARY_DIR}"/constants/datacenter_consts.json      
         
echo 'Overlay network scripts provisioned.'
echo 'Creating Docker overlay network ...'

get_datacenter_instance "${instance_key}" 'UserPassword'
user_pwd="${__RESULT}"

ssh_run_remote_command_as_root "chmod -R +x ${remote_dir}/overlaynet" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}" \
    "${user_pwd}"   

ssh_run_remote_command_as_root "${remote_dir}"/overlaynet/overlaynet-install.sh \
       "${private_key_file}" \
       "${eip}" \
       "${ssh_port}" \
       "${user_nm}" \
       "${user_pwd}" >> "${LOGS_DIR}"/"${logfile_nm}" && echo 'Docker overlay network successully installed.' ||
       {
          echo 'ERROR: installing Docker overlay network.'
          exit 1
       } 
       
ssh_run_remote_command "rm -rf ${remote_dir:?}" \
    "${private_key_file}" \
    "${eip}" \
    "${ssh_port}" \
    "${user_nm}"        
      
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

get_datacenter_application_port "${instance_key}" "${swarm_key}" 'ClusterPort'
cluster_port="${__RESULT}"
ec2_check_access_is_granted "${sgp_id}" "${cluster_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   ec2_allow_access_from_cidr "${sgp_id}" "${cluster_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access granted on ${cluster_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${cluster_port} tcp 0.0.0.0/0."
fi

get_datacenter_application_port "${instance_key}" "${swarm_key}" 'NodesPort'
nodes_port="${__RESULT}"
ec2_check_access_is_granted "${sgp_id}" "${nodes_port}" 'tcp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   ec2_allow_access_from_cidr "${sgp_id}" "${nodes_port}" 'tcp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access granted on ${nodes_port} tcp 0.0.0.0/0."
else
   echo "WARN: access already granted ${nodes_port} tcp 0.0.0.0/0."
fi

ec2_check_access_is_granted "${sgp_id}" "${nodes_port}" 'udp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   ec2_allow_access_from_cidr "${sgp_id}" "${nodes_port}" 'udp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access granted on ${nodes_port} udp 0.0.0.0/0."
else
   echo "WARN: access already granted ${nodes_port} udp 0.0.0.0/0."
fi

get_datacenter_application_port "${instance_key}" "${swarm_key}" 'TrafficPort'
traffic_port="${__RESULT}"
ec2_check_access_is_granted "${sgp_id}" "${traffic_port}" 'udp' '0.0.0.0/0'
is_granted="${__RESULT}"

if [[ 'false' == "${is_granted}" ]]
then
   ec2_allow_access_from_cidr "${sgp_id}" "${traffic_port}" 'udp' '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Access granted on ${traffic_port} udp 0.0.0.0/0."
else
   echo "WARN: access already granted ${traffic_port} udp 0.0.0.0/0."
fi

# Removing old files
# shellcheck disable=SC2115
rm -rf  "${temporary_dir:?}" 

echo  

