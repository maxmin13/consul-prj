#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

####
STEP 'Admin Consul'
####

SCRIPTS_DIR=/home/"${USER_NM}"/script
CONSUL_SECRET_NM='consulkey'

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

get_instance_id "${ADMIN_INST_NM}"
instance_id="${__RESULT}"

if [[ -z "${instance_id}" ]]
then
   echo '* WARN: Admin instance not found.'
fi

if [[ -n "${instance_id}" ]]
then
   get_instance_state "${ADMIN_INST_NM}"
   instance_st="${__RESULT}"
   
   if [[ 'running' == "${instance_st}" ]]
   then
      echo "* Admin box ready (${instance_st})."
   else
      echo "* WARN: Admin box is not ready. (${instance_st})."
   fi
fi

get_security_group_id "${ADMIN_INST_SEC_GRP_NM}"
admin_sgp_id="${__RESULT}"

if [[ -z "${admin_sgp_id}" ]]
then
   echo '* WARN: Admin security group not found.'
else
   echo "* Admin security group ID: ${admin_sgp_id}."
fi


# Get the public IP address assigned to the instance. 
get_public_ip_address_associated_with_instance "${ADMIN_INST_NM}"
admin_eip="${__RESULT}"

if [[ -z "${admin_eip}" ]]
then
   echo '* WARN: Admin public IP address not found.'
else
   echo "* Admin public IP address: ${admin_eip}."
fi

# Removing old files
# shellcheck disable=SC2115
admin_tmp_dir="${TMP_DIR}"/consul
rm -rf  "${admin_tmp_dir:?}"
mkdir -p "${admin_tmp_dir}"

echo

if [[ -n "${instance_id}" && 'running' == "${instance_st}" ]]
then
   #
   # Permissions.
   #

   check_instance_profile_has_role_associated "${ADMIN_INST_PROFILE_NM}" "${ADMIN_AWS_ROLE_NM}" 
   is_role_associated="${__RESULT}"

   if [[ 'false' == "${is_role_associated}" ]]
   then
      associate_role_to_instance_profile "${ADMIN_INST_PROFILE_NM}" "${ADMIN_AWS_ROLE_NM}"
      
      # IAM is a bit slow, progress only when the role is associated to the profile. 
      check_instance_profile_has_role_associated "${ADMIN_INST_PROFILE_NM}" "${ADMIN_AWS_ROLE_NM}" && \
      echo 'Role associated to the instance profile.' ||
      {
         echo 'The role has not been associated to the profile yet.'
         echo 'Let''s wait a bit and check again (first time).' 
      
         wait 180  
      
         echo 'Let''s try now.' 
      
         check_instance_profile_has_role_associated "${ADMIN_INST_PROFILE_NM}" "${ADMIN_AWS_ROLE_NM}" && \
         echo 'Role associated to the instance profile.' ||
         {
            echo 'ERROR: the role has not been associated to the profile after 3 minutes.'
            exit 1
         }
      } 
   else
      echo 'WARN: role already associated to the instance profile.'
   fi 

   check_role_has_permission_policy_attached "${ADMIN_AWS_ROLE_NM}" "${SECRETSMANAGER_POLICY_NM}"
   is_permission_policy_associated="${__RESULT}"

   if [[ 'false' == "${is_permission_policy_associated}" ]]
   then
      echo 'Associating permission policy the instance role ...'

      attach_permission_policy_to_role "${ADMIN_AWS_ROLE_NM}" "${SECRETSMANAGER_POLICY_NM}"
      
      # IAM is a bit slow, progress only when the role is associated to the profile. 
      check_role_has_permission_policy_attached "${ADMIN_AWS_ROLE_NM}" "${SECRETSMANAGER_POLICY_NM}" && \
      echo 'Permission policy associated to the role.' ||
      {
         echo 'The permission policy has not been associated to the role yet.'
         echo 'Let''s wait a bit and check again (first time).' 
      
         wait 180  
      
         echo 'Let''s try now.' 
      
         check_role_has_permission_policy_attached "${ADMIN_AWS_ROLE_NM}" "${SECRETSMANAGER_POLICY_NM}" && \
         echo 'Permission policy associated to the role.' ||
         {
            echo 'ERROR: the permission policy has not been associated to the role after 3 minutes.'
            exit 1
         }
      } 
   else
      echo 'WARN: permission policy already associated to the role.'
   fi 

   #
   # Firewall rules
   #

   set +e 
   allow_access_from_cidr "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   set -e

   echo 'Provisioning the Admin instance ...'
 
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
       -e "s/SEDdtc_regionSED/${DTC_REGION}/g" \
       -e "s/SEDconsul_service_file_nmSED/consul.service/g" \
       -e "s/SEDconsul_secret_nmSED/${CONSUL_SECRET_NM}/g" \
          "${SERVICES_DIR}"/consul/consul-remove.sh > "${admin_tmp_dir}"/consul-remove.sh  
     
   echo 'consul-remove.sh ready.' 

   scp_upload_files "${private_key_file}" "${admin_eip}" "${SHARED_INST_SSH_PORT}" "${USER_NM}" "${SCRIPTS_DIR}" \
       "${LIBRARY_DIR}"/general_utils.sh \
       "${LIBRARY_DIR}"/secretsmanager.sh \
       "${admin_tmp_dir}"/consul-remove.sh 
         
   echo 'Consul scripts provisioned.'
   
   ssh_run_remote_command_as_root "chmod -R +x ${SCRIPTS_DIR}" \
       "${private_key_file}" \
       "${admin_eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${USER_NM}" \
       "${USER_PWD}"  

   # shellcheck disable=SC2015
   ssh_run_remote_command_as_root "${SCRIPTS_DIR}/consul-remove.sh" \
       "${private_key_file}" \
       "${admin_eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${USER_NM}" \
       "${USER_PWD}" && echo 'Consul server successfully removed.' ||
       { 
          echo 'ERROR: removing Consul.'
          exit 1
       }
    
   ssh_run_remote_command "rm -rf ${SCRIPTS_DIR}" \
       "${private_key_file}" \
       "${admin_eip}" \
       "${SHARED_INST_SSH_PORT}" \
       "${USER_NM}"     

   #
   # Permissions.
   #

   check_role_has_permission_policy_attached "${ADMIN_AWS_ROLE_NM}" "${SECRETSMANAGER_POLICY_NM}"
   is_permission_policy_associated="${__RESULT}"

   if [[ 'true' == "${is_permission_policy_associated}" ]]
   then
      detach_permission_policy_from_role "${ADMIN_AWS_ROLE_NM}" "${SECRETSMANAGER_POLICY_NM}"
      
      echo 'Permission policy detached.'
   else
      echo 'WARN: permission policy already detached from the role.'
   fi    

   #
   # Firewall rules
   #

   set +e
   revoke_access_from_cidr "${admin_sgp_id}" "${SHARED_INST_SSH_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   revoke_access_from_cidr "${admin_sgp_id}" "${ADMIN_CONSUL_SERVER_SERF_LAN_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   revoke_access_from_cidr "${admin_sgp_id}" "${ADMIN_CONSUL_SERVER_SERF_LAN_PORT}" 'udp' '0.0.0.0/0' > /dev/null 2>&1
   revoke_access_from_cidr "${admin_sgp_id}" "${ADMIN_CONSUL_SERVER_SERF_WAN_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   revoke_access_from_cidr "${admin_sgp_id}" "${ADMIN_CONSUL_SERVER_SERF_WAN_PORT}" 'udp' '0.0.0.0/0' > /dev/null 2>&1
   revoke_access_from_cidr "${admin_sgp_id}" "${ADMIN_CONSUL_SERVER_RPC_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   revoke_access_from_cidr "${admin_sgp_id}" "${ADMIN_CONSUL_SERVER_HTTP_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   revoke_access_from_cidr "${admin_sgp_id}" "${ADMIN_CONSUL_SERVER_DNS_PORT}" 'tcp' '0.0.0.0/0' > /dev/null 2>&1
   revoke_access_from_cidr "${admin_sgp_id}" "${ADMIN_CONSUL_SERVER_DNS_PORT}" 'udp' '0.0.0.0/0' > /dev/null 2>&1
   set -e 

   ## Clearing
   rm -rf "${TMP_DIR:?}"
   mkdir -p "${TMP_DIR}"
fi

echo 'Admin Consul deleted.'
echo
