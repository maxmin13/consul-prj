#!/usr/bin/bash

# shellcheck disable=SC2002

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: ec2_consts_utils.sh
#   DESCRIPTION: The script contains general Bash functions.
#       GLOBALS: None
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#
#   Retrieve the values in ec2_consts.json file.
#
#===============================================================================

#===============================================================================
# Retrieves the value of the Instance.UserName property in the file 
# ec2_constants.json
# Globals:
#  None
# Arguments:
#  none
# Returns:      
#  the username value in the __RESULT variable.  
#===============================================================================
function get_user_name()
{
   __RESULT=''
   local exit_code=0
   local user_nm=''
   
   user_nm=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r -c '.Instance.UserName')
   	
   __RESULT="${user_nm}"
   
   return "${exit_code}"
}

#===============================================================================
# Retrieves the value of the Instance.UserPassword property in the file 
# ec2_constants.json
# Globals:
#  None
# Arguments:
#  none
# Returns:      
#  the user password value in the __RESULT variable.  
#===============================================================================
function get_user_password()
{
   __RESULT=''
   local exit_code=0
   local user_pwd=''
   
   user_pwd=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r -c '.Instance.UserPassword')
   	
   __RESULT="${user_pwd}"
   
   return "${exit_code}"
}

#===============================================================================
# Retrieves the value of the InstanceProfileName property in the file ec2_constants.json, 
# filtering by the Key field.
# Globals:
#  None
# Arguments:
# +instance_key -- the value of the Name property in the document.
# Returns:      
#  the InstanceProfileName property value in the __RESULT variable.  
#===============================================================================
function get_instance_profile_name()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r instance_key="${1}"
   local instance_profile_name=''
   
   instance_profile_name=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r --arg key "${instance_key}" -c '.Instance.Boxes[] | select(.Name | index($key))' |
   	   jq -r -c '.InstanceProfileName')
   	
   __RESULT="${instance_profile_name}"
   
   return "${exit_code}"
}

#===============================================================================
# Retrieves the an instance consul mode, either client or server.
# Globals:
#  None
# Arguments:
# +instance_key -- the value of the Name property in the configuration file.
# Returns:      
#  the consul mode in the __RESULT variable.  
#===============================================================================
function get_consul_mode()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r instance_key="${1}"
   local consul_mode=''
   
   consul_mode=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r --arg key "${instance_key}" -c '.Instance.Boxes[] | select(.Name | index($key))' |
   	   jq -r -c '.ConsulMode')
   	
   __RESULT="${consul_mode}"
   
   return "${exit_code}"
}

#===============================================================================
# Retrieves the value of the RoleName property in the file ec2_constants.json, 
# filtering by the Key field.
# Globals:
#  None
# Arguments:
# +instance_key -- the value of the Name property in the document.
# Returns:      
#  the RoleName property value in the __RESULT variable.  
#===============================================================================
function get_role_name()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r instance_key="${1}"
   local role_name=''
   
   role_name=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r --arg key "${instance_key}" -c '.Instance.Boxes[] | select(.Name | index($key))' |
   	   jq -r -c '.RoleName')
   	
   __RESULT="${role_name}"
   
   return "${exit_code}"
}

#===============================================================================
# Retrieves the value of the KeypairName property in the file ec2_constants.json, 
# filtering by the Key field.
# Globals:
#  None
# Arguments:
# +instance_key -- the value of the Name property in the document.
# Returns:      
#  the KeypairName property value in the __RESULT variable.  
#===============================================================================
function get_keypair_name()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r instance_key="${1}"
   local keypair_name=''
   
   keypair_name=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r --arg key "${instance_key}" -c '.Instance.Boxes[] | select(.Name | index($key))' | 
   	   jq -r -c '.KeypairName')
   	
   __RESULT="${keypair_name}"
   
   return "${exit_code}"
}

#===============================================================================
# Retrieves the value of the SgpName property in the file ec2_constants.json, 
# filtering by the Key field.
# Globals:
#  None
# Arguments:
# +instance_key -- the value of the Name property in the document.
# Returns:      
#  the SgpName property value in the __RESULT variable.  
#===============================================================================
function get_security_group_name()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r instance_key="${1}"
   local sgp_name=''
   
   sgp_name=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r --arg key "${instance_key}" -c '.Instance.Boxes[] | select(.Name | index($key))' | 
   	   jq -r -c '.SgpName')
   	
   __RESULT="${sgp_name}"
   
   return "${exit_code}"
}

#===============================================================================
# Retrieves the value of the HostName property in the file ec2_constants.json, 
# filtering by the Key field.
# Globals:
#  None
# Arguments:
# +instance_key -- the value of the Name property in the document.
# Returns:      
#  the HostName property value in the __RESULT variable.  
#===============================================================================
function get_hostname()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r instance_key="${1}"
   local hostname=''
   
   hostname=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r --arg key "${instance_key}" -c '.Instance.Boxes[] | select(.Name | index($key))' |
   	   jq -r -c '.Hostname')
   	
   __RESULT="${hostname}"
   
   return "${exit_code}"
}

#===============================================================================
# Retrieves the value of the PrivateIP field in the file ec2_constants.json, 
# filtering by the Key field.
# Globals:
#  None
# Arguments:
# +instance_key -- the value of the Name property in the document.
# Returns:      
#  the PrivateIP field value in the __RESULT variable.  
#===============================================================================
function get_private_ip()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r instance_key="${1}"
   local private_ip=''
   
   private_ip=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r --arg key "${instance_key}" -c '.Instance.Boxes[] | select(.Name | index($key))' |
   	   jq -r -c '.PrivateIP')
   	
   __RESULT="${private_ip}"
   
   return "${exit_code}"
}

#===============================================================================
# Retrieves the value of the InstanceName property in the file ec2_constants.json, 
# filtering by the Key field.
# Globals:
#  None
# Arguments:
# +instance_key -- the value of the Name property in the document.
# Returns:      
#  the InstanceName property value in the __RESULT variable.  
#===============================================================================
function get_instance_name()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r instance_key="${1}"
   local instance_name=''
   
   instance_name=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r --arg key "${instance_key}" -c '.Instance.Boxes[] | select(.Name | index($key))' | 
   	   jq -r -c '.InstanceName')
   	
   __RESULT="${instance_name}"
   
   return "${exit_code}"
}

#===============================================================================
# Retrieves the value of the ParentImageName property in the file  
# ec2_constants.json, filtering by the Key field.
# Globals:
#  None
# Arguments:
# +instance_key -- the value of the Name property in the document.
# Returns:      
#  the ParentImageName property value in the __RESULT variable.  
#===============================================================================
function get_parent_image_name()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r instance_key="${1}"
   local parent_image_nm=''
   
   parent_image_nm=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r --arg key "${instance_key}" -c '.Instance.Boxes[] | select(.Name | index($key))' |
   	   jq -r -c '.ParentImageName')
   	
   __RESULT="${parent_image_nm}"
   
   return "${exit_code}"
}

#===============================================================================
# Retrieves the value of the TargetImageName property in the file  
# ec2_constants.json, filtering by the Key field.
# Globals:
#  None
# Arguments:
# +instance_key -- the value of the Name property in the document.
# Returns:      
#  the TargetImageName property value in the __RESULT variable.  
#===============================================================================
function get_target_image_name()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r instance_key="${1}"
   local target_image_name=''
   
   target_image_name=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r --arg key "${instance_key}" -c '.Instance.Boxes[] | select(.Name | index($key))' |
   	   jq -r -c '.TargetImageName')
   
   __RESULT="${target_image_name}"
   
   return "${exit_code}"
}

#===============================================================================
# Retrieves the value of the datacenter name.
# Globals:
#  None
# Arguments:
#  none
# Returns:      
#  the datacenter name in the __RESULT variable.  
#===============================================================================
function get_datacenter_name()
{
   __RESULT=''
   local exit_code=0
   local datacenter_name=''
   
   datacenter_name=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r -c '.Datacenter.Name')
   
   __RESULT="${datacenter_name}"
   
   return "${exit_code}"
}

#===============================================================================
# Retrieves the value of the datacenter CIDR.
# Globals:
#  None
# Arguments:
#  none
# Returns:      
#  the datacenter CIDR in the __RESULT variable.  
#===============================================================================
function get_datacenter_cidr()
{
   __RESULT=''
   local exit_code=0
   local datacenter_cidr=''
   
   datacenter_cidr=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r -c '.Datacenter.DctCidr')
   
   __RESULT="${datacenter_cidr}"
   
   return "${exit_code}"
}


#===============================================================================
# Retrieves the internet gateway name.
# Globals:
#  None
# Arguments:
#  none
# Returns:      
#  the internet gateway name in the __RESULT variable.  
#===============================================================================
function get_internet_gateway_name()
{
   __RESULT=''
   local exit_code=0
   local gateway_name=''
   
   gateway_name=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r -c '.Datacenter.Gateway')
   
   __RESULT="${gateway_name}"
   
   return "${exit_code}"
}

#===============================================================================
# Retrieves the route table name.
# Globals:
#  None
# Arguments:
#  none
# Returns:      
#  the route table name in the __RESULT variable.  
#===============================================================================
function get_route_table_name()
{
   __RESULT=''
   local exit_code=0
   local route_table_name=''
   
   route_table_name=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r -c '.Datacenter.RouteTable')
   
   __RESULT="${route_table_name}"
   
   return "${exit_code}"
}

#===============================================================================
# Retrieves the subnet name.
# Globals:
#  None
# Arguments:
#  none
# Returns:      
#  the subnet name in the __RESULT variable.  
#===============================================================================
function get_subnet_name()
{
   __RESULT=''
   local exit_code=0
   local subnet_name=''
   
   subnet_name=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r -c '.Datacenter.Subnet')
   
   __RESULT="${subnet_name}"
   
   return "${exit_code}"
}

#===============================================================================
# Retrieves the subnet CIDR.
# Globals:
#  None
# Arguments:
#  none
# Returns:      
#  the subnet CIDR in the __RESULT variable.  
#===============================================================================
function get_subnet_cidr()
{
   __RESULT=''
   local exit_code=0
   local subnet_cidr=''
   
   subnet_cidr=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r -c '.Datacenter.SubnetCidr')
   
   __RESULT="${subnet_cidr}"
   
   return "${exit_code}"
}

#===============================================================================
# Retrieves the region name.
# Globals:
#  None
# Arguments:
#  none
# Returns:      
#  the region name in the __RESULT variable.  
#===============================================================================
function get_region_name()
{
   __RESULT=''
   local exit_code=0
   local region_name=''
   
   region_name=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r -c '.Datacenter.Region')
   
   __RESULT="${region_name}"
   
   return "${exit_code}"
}

#===============================================================================
# Retrieves the availability zone name.
# Globals:
#  None
# Arguments:
#  none
# Returns:      
#  the availability zone name in the __RESULT variable.  
#===============================================================================
function get_availability_zone_name()
{
   __RESULT=''
   local exit_code=0
   local az_name=''
   
   az_name=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r -c '.Datacenter.Az')
   
   __RESULT="${az_name}"
   
   return "${exit_code}"
}

#===============================================================================
# Retrieves the application home directory in the host machine.
# Globals:
#  None
# Arguments:
# +application_key -- the value of the Name property in the document.
# Returns:      
#  the home directory in the __RESULT variable.  
#===============================================================================
function get_application_home()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r application_key="${1}"
   local home=''
   
   home=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r --arg key "${application_key}" -c '.Applications[] | select(.Name | index($key))' |
   	   jq -r -c '.Home')

   # shellcheck disable=SC2034
   __RESULT="${home}"
   
   return "${exit_code}"
}

#===============================================================================
# Retrieves the application port exposed by the container.
# Globals:
#  None
# Arguments:
# +application_key -- the value of the Name property in the document.
# Returns:      
#  the port in the __RESULT variable.  
#===============================================================================
function get_application_port()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r application_key="${1}"
   local port=''
   
   port=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r --arg key "${application_key}" -c '.Applications[] | select(.Name | index($key))' |
   	   jq -r -c '.Port')
   
   __RESULT="${port}"
   
   return "${exit_code}"
}

function get_application_rpcport()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r application_key="${1}"
   local port=''
   
   port=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r --arg key "${application_key}" -c '.Applications[] | select(.Name | index($key))' |
   	   jq -r -c '.RpcPort')
   
   __RESULT="${port}"
   
   return "${exit_code}"
}

function get_application_serflanport()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r application_key="${1}"
   local port=''
   
   port=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r --arg key "${application_key}" -c '.Applications[] | select(.Name | index($key))' |
   	   jq -r -c '.SerfLanPort')
   
   __RESULT="${port}"
   
   return "${exit_code}"
}

function get_application_serfwanport()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r application_key="${1}"
   local port=''
   
   port=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r --arg key "${application_key}" -c '.Applications[] | select(.Name | index($key))' |
   	   jq -r -c '.SerfWanPort')
   
   __RESULT="${port}"
   
   return "${exit_code}"
}

function get_application_httpport()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r application_key="${1}"
   local port=''
   
   port=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r --arg key "${application_key}" -c '.Applications[] | select(.Name | index($key))' |
   	   jq -r -c '.HttpPort')
   
   __RESULT="${port}"
   
   return "${exit_code}"
}

function get_application_dnsport()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r application_key="${1}"
   local port=''
   
   port=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r --arg key "${application_key}" -c '.Applications[] | select(.Name | index($key))' |
   	   jq -r -c '.DnsPort')
   
   __RESULT="${port}"
   
   return "${exit_code}"
}

function get_application_security_key_name()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r application_key="${1}"
   local key=''
   
   key=$(cat "${LIBRARY_DIR}"/constants/ec2_consts.json | 
   	jq -r --arg key "${application_key}" -c '.Applications[] | select(.Name | index($key))' |
   	   jq -r -c '.SecurityKey')
  
   # shellcheck disable=SC2034
   __RESULT="${key}"
   
   return "${exit_code}"
}
