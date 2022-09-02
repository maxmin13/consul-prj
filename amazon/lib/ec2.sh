#!/usr/bin/bash

set -o errexit
## turn on -e in subshells
##shopt -s inherit_errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: ec2.sh
#   DESCRIPTION: the script contains functions that use AWS client to make 
#                calls to Amazon Elastic Compute Cloud (Amazon EC2).
#       GLOBALS: None
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#===============================================================================

#===============================================================================
# Returns the data center identifier.
#
# Globals:
#  None
# Arguments:
# +dtc_nm -- the data center name.
# Returns:      
#  the data center identifier in the global __RESULT variable.  
#===============================================================================
function get_datacenter_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r dtc_nm="${1}"
   local dtc_id=''
 
   dtc_id="$(aws ec2 describe-vpcs \
       --filters Name=tag-key,Values='Name' \
       --filters Name=tag-value,Values="${dtc_nm}" \
       --query 'Vpcs[*].VpcId' \
       --output text)" 
       
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: getting datacenter ID.'
      return "${exit_code}"
   fi 

   __RESULT="${dtc_id}"
   
   return "${exit_code}"
}

#===============================================================================
# Creates a data center and waits for it to become available.
#
# Globals:
#  None
# Arguments:
# +dtc_nm -- the data center name.
# Returns:      
#  none.  
#===============================================================================
function create_datacenter()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
  
   local exit_code=0
   local -r dtc_nm="${1}"
  
   aws ec2 create-vpc \
       --cidr-block "${DTC_CDIR}" \
       --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value='${dtc_nm}'}]" \
      
       
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: creating datacenter.'
      return "${exit_code}"
   fi     
            
   aws ec2 wait vpc-available \
       --filters Name=tag-key,Values='Name' \
       --filters Name=tag-value,Values="${dtc_nm}"  
 
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: waiting for available datacenter.'
   fi  
  
   return "${exit_code}"
}

#===============================================================================
# Delete a data center.
#
# Globals:
#  None
# Arguments:
# +dtc_nm -- the data center name.
# Returns:      
#  None.  
#===============================================================================
function delete_datacenter()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
  
   local exit_code=0
   local -r dtc_id="${1}"
  
   aws ec2 delete-vpc --vpc-id "${dtc_id}"
  
   exit_code=$?    
  
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting datacenter.'
   fi 
   
   return "${exit_code}"
}

#===============================================================================
# Returns a JSON string representing the list of the subnet 
# identifiers in a Data Center. Ex:
#
# subnet ids: '[
#     "subnet-016a221d033705c44",
#     "subnet-0861aef5e928a45bd"
# ]'
#
# If the data center is not found or if the data center doesn't have any subnet, the string
# '[]' is returned. 
#
# Globals:
#  None
# Arguments:
# +dtc_id -- the data center identifier.
# Returns:      
#  A JSON string containing the list of subnet identifiers in a data center in
#  the global __RESULT variable.
#===============================================================================
function get_subnet_ids()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r dtc_id="${1}"
   local subnet_ids=''
   
   subnet_ids="$(aws ec2 describe-subnets \
       --filters Name=vpc-id,Values="${dtc_id}" \
       --query 'Subnets[*].SubnetId')" 
  
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: getting subnet IDs.'
      return "${exit_code}"
   fi 

   __RESULT="${subnet_ids}"
   
   return "${exit_code}"
}

#===============================================================================
# Returns the the subnet identifyer.
#
# Globals:
#  None
# Arguments:
# +subnet_nm -- the subnet name.
# Returns:      
#  the subnet identifier in the global __RESULT variable.
#===============================================================================
function get_subnet_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r subnet_nm="${1}"
   local subnet_id=''
  
   subnet_id="$(aws ec2 describe-subnets \
      --filters Name=tag-key,Values='Name' \
      --filters Name=tag-value,Values="${subnet_nm}" \
      --query 'Subnets[*].SubnetId' \
      --output text)"
  
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: getting subnet IDs.'
      return "${exit_code}"
   fi 

   __RESULT="${subnet_id}"
   
   return "${exit_code}"
}

#===============================================================================
# Creates a subnet and waits until it becomes available. the subnet is 
# associated with the route Table.
#
# Globals:
#  None
# Arguments:
# +subnet_nm   -- the subnet name.
# +subnet_cidr -- the subnet CIDR.
# +subnet_az   -- the subnet Availability Zone.
# +dtc_id      -- the data center identifier.
# +rtb_id      -- the route table identifier.
# Returns:      
#  none.  
#===============================================================================
function create_subnet()
{
   if [[ $# -lt 5 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r subnet_nm="${1}"
   local -r subnet_cidr="${2}"
   local -r subnet_az="${3}"
   local -r dtc_id="${4}"
   local -r rtb_id="${5}"
   local subnet_id=''
 
   subnet_id="$(aws ec2 create-subnet \
      --vpc-id "${dtc_id}" \
      --cidr-block "${subnet_cidr}" \
      --availability-zone "${subnet_az}" \
      --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value='${subnet_nm}'}]" \
      --query 'Subnet.SubnetId' \
      --output text)"
       
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: creating subnet.'
      return "${exit_code}"
   fi     
 
   aws ec2 wait subnet-available --filters Name=tag-key,Values=Name \
       --filters Name=tag-value,Values="${subnet_nm}"
       
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: waiting fo subnet.'
      return "${exit_code}"
   fi        
  
   ## Associate this subnet with our route table 
   aws ec2 associate-route-table --subnet-id "${subnet_id}" --route-table-id "${rtb_id}"
  
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: associating subnet to the route table.'
   fi  
 
   return "${exit_code}"
}

#===============================================================================
# Deletes a subnet.
#
# Globals:
#  None
# Arguments:
# +subnet_id -- the subnet identifier.
# Returns:      
#  None.  
#===============================================================================
function delete_subnet()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r subnet_id="${1}"
 
   aws ec2 delete-subnet --subnet-id "${subnet_id}"
 
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting subnet.'
   fi  
 
   return "${exit_code}"
}

#============================================================================
# Returns an internet gateway's identifier.
# Globals:
#  None
# Arguments:
# +igw_nm -- the internet gateway name.
# Returns:      
#  the internet gateway identifier in the __RESULT global variable.  
#===============================================================================
function get_internet_gateway_id()
{
   if [[ $# -lt 1 ]]
   then
     echo 'ERROR: missing mandatory arguments.'
     return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r igw_nm="${1}"
   local igw_id=''
  
   igw_id="$(aws ec2 describe-internet-gateways \
       --filters Name=tag-key,Values='Name' \
       --filters Name=tag-value,Values="${igw_nm}" \
       --query 'InternetGateways[*].InternetGatewayId' \
       --output text)"
  
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: getting internet gateway ID.'
      return "${exit_code}"
   fi 

   __RESULT="${igw_id}"
   
   return "${exit_code}"
}

#============================================================================
# Returns the current state of the attachment between the gateway and the 
# VPC (data center, virtual private cloud). Present only if a VPC is 
# attached.
#
# Globals:
#  None
# Arguments:
# +igw_nm -- the internet gateway name.
# +dtc_id -- the data center identifier.
# Returns:      
#  the attachment status in the __RESULT global variable.  
#===============================================================================
function get_internet_gateway_attachment_status()
{
   if [[ $# -lt 2 ]]
   then
     echo 'ERROR: missing mandatory arguments.'
     return 128
  fi

   __RESULT=''
   local exit_code=0
   local -r igw_nm="${1}"
   local -r dtc_id="${2}"
   local attachment_status=''
  
   attachment_status="$(aws ec2 describe-internet-gateways \
       --filters Name=tag-key,Values='Name' \
       --filters Name=tag-value,Values="${igw_nm}" \
       --query "InternetGateways[*].Attachments[?VpcId=='${dtc_id}'].[State]" \
       --output text)"
  
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: getting internet gateway attachment status.'
      return "${exit_code}"
   fi 

   __RESULT="${attachment_status}"
   
   return "${exit_code}"
}

#===============================================================================
# Creates internet gateway used for subnets to reach internet.
# The internet gateway has to be attached to the VPC.
#
# Globals:
#  None
# Arguments:
# +igw_nm -- the internet gateway name.
# Returns:      
#  none.  
#===============================================================================
function create_internet_gateway()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
  
   local exit_code=0
   local -r igw_nm="${1}"
  
   aws ec2 create-internet-gateway \
       --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value='${igw_nm}'}]" \
      
  
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: creating internet gateway.'
   fi  
 
   return "${exit_code}"
}

#===============================================================================
# Deletes an Internet Gateway.
#
# Globals:
#  None
# Arguments:
# +igw_id -- the internet gateway identifier.
# Returns:      
#  None  
#===============================================================================
function delete_internet_gateway()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
  
   local exit_code=0
   local -r igw_id="${1}"
 
   aws ec2 delete-internet-gateway --internet-gateway-id "${igw_id}"
  
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting internet gateway.'
   fi  
 
   return "${exit_code}"
}

#===============================================================================
# Attaches an internet gateway to a data center.
#
# Globals:
#  None
# Arguments:
# +igw_id -- the internet gateway identifier.
# +dtc_id -- the data center ID.
# Returns:      
#  none.
#===============================================================================
function attach_internet_gateway()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
  
   local exit_code=0
   local -r igw_id="${1}"
   local -r dtc_id="${2}"
  
   aws ec2 attach-internet-gateway --vpc-id "${dtc_id}" --internet-gateway-id "${igw_id}"
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: attaching internet gateway to VPC.'
   fi  
 
   return "${exit_code}"
}

#===============================================================================
# Returns the the route table identifyer.
#
# Globals:
#  None
# Arguments:
# +rtb_nm -- the route table name.
# Returns:      
#  the route table identifier in the __RESULT global variable.  
#===============================================================================
function get_route_table_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r rtb_nm="${1}"
   local rtb_id=''
  
   rtb_id="$(aws ec2 describe-route-tables \
       --filters Name=tag-key,Values='Name' \
       --filters Name=tag-value,Values="${rtb_nm}" \
       --query 'RouteTables[*].RouteTableId' \
       --output text)"
  
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving route table ID.'
      return "${exit_code}"
   fi 

   __RESULT="${rtb_id}"
   
   return "${exit_code}"
}

#===============================================================================
# Creates a custom route Table.
#
# Globals:
#  None
# Arguments:
# +rtb_nm -- the route table name.
# +dtc_id -- the data center identifier.
# Returns:      
#  none.  
#===============================================================================
function create_route_table()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r rtb_nm="${1}"
   local -r dtc_id="${2}"
  
   aws ec2 create-route-table \
       --vpc-id "${dtc_id}" \
       --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value='${rtb_nm}'}]" \
       
 
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: creating route table.'
   fi  
 
   return "${exit_code}"
}

#===============================================================================
# Delete a route Table.
#
# Globals:
#  None
# Arguments:
# +rtb_id -- the route table identifier.

# Returns:      
#  none.  
#===============================================================================
function delete_route_table()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r rtb_id="${1}"
  
   aws ec2 delete-route-table --route-table-id "${rtb_id}"
 
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting route table.'
   fi  
 
   return "${exit_code}"
}

#===============================================================================
# Creates a route in a route table.
#
# Globals:
#  None
# Arguments:
# +rtb_id           -- the route table identifier.
# +target_id        -- the target identifier, for ex: an Internet Gateway.
# +destination_cidr -- the CIDR address block used to match the destination
#                      of the incoming traffic.
# Returns:      
#  none.
#===============================================================================
function set_route()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r rtb_id="${1}"
   local -r target_id="${2}"
   local -r destination_cidr="${3}"
   
   aws ec2 create-route --route-table-id "${rtb_id}" \
       --destination-cidr-block "${destination_cidr}" \
       --gateway-id "${target_id}" \
       

   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: setting route in route table.'
   fi  
 
   return "${exit_code}"
}

#===============================================================================
# Returns the the security group identifyer.
#
# Globals:
#  None
# Arguments:
# +sgp_nm -- the security group name.
# Returns:      
#  the security group identifier int global __RESULT variable.  
#===============================================================================
function get_security_group_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r sgp_nm="${1}"
   local sgp_id=''
  
   sgp_id="$(aws ec2 describe-security-groups \
         --filters Name=tag-key,Values='Name' \
         --filters Name=tag-value,Values="${sgp_nm}" \
         --query 'SecurityGroups[*].GroupId' \
         --output text)"
         
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving security group ID.'
      return "${exit_code}"
   fi 

   __RESULT="${sgp_id}"
   
   return "${exit_code}"
}

#===============================================================================
# Creates a security group.
# A security group acts as a virtual firewall for your instance to control 
# inbound and outbound traffic.
# Security groups act at the instance level, not the subnet level. Therefore, 
# each instance in a subnet in your VPC can be assigned to a different set of 
# security groups.
#
# Globals:
#  None
# Arguments:
# +dtc_id        -- the data center identifier.
# +sgp_nm        -- the security group name.
# +sgp_desc      -- the security group description.
# Returns:      
#  none.  
#===============================================================================
function create_security_group()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r dtc_id="${1}" 
   local -r sgp_nm="${2}"
   local -r sgp_desc="${3}"  
      
   aws ec2 create-security-group \
        --group-name "${sgp_nm}" \
        --description "${sgp_desc}" \
        --vpc-id "${dtc_id}" \
        --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value='${sgp_nm}'}]" \
        
        
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: creating security group.'
   fi  
 
   return "${exit_code}"
}

#===============================================================================
# Deletes a security group.
#
# Globals:
#  None
# Arguments:
# +sgp_id -- the security group identifier.
# Returns:      
#  None    
#===============================================================================
function delete_security_group()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r sgp_id="${1}"
      
   aws ec2 delete-security-group --group-id "${sgp_id}" 
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting security group.'
   fi  
 
   return "${exit_code}"
}

#===============================================================================
# Deletes a security group.
#
# Globals:
#  None
# Arguments:
# +sgp_id -- the security group identifier.
# Returns:      
#  None    
#===============================================================================
function delete_security_group_and_wait()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r sgp_id="${1}"
      
   # shellcheck disable=SC2015
   delete_security_group "${sgp_id}" || 
   {
      wait 60
      delete_security_group "${sgp_id}" || 
      {
         wait 60
         delete_security_group "${sgp_id}" || 
         {
            echo 'ERROR: deleting security group.'
            exit_code=1
         }         
      } 
   }   
 
   return "${exit_code}"
}

#===============================================================================
# Allow access to the traffic incoming from a CIDR block.  
#
# Globals:
#  None
# Arguments:
# +sgp_id    -- the security group identifier.
# +port      -- the TCP port
# +protocol  -- the IP protocol name (tcp , udp , icmp , icmpv6), default is tcp. 
# +from_cidr -- the CIDR block representing the origin of the traffic.
# Returns:      
#  none.
#===============================================================================
function allow_access_from_cidr()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r sgp_id="${1}"
   local -r port="${2}"
   local -r protocol="${3}"
   local -r from_cidr="${4}"
   
   aws ec2 authorize-security-group-ingress \
       --group-id "${sgp_id}" \
       --protocol "${protocol}" \
       --port "${port}" \
       --cidr "${from_cidr}" 

   exit_code=$?

   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: allowing access from CIDR.'
   fi  
 
   return "${exit_code}"
}

#===============================================================================
# Allows access to the traffic incoming from another security group.
#
# Globals:
#  None
# Arguments:
# +sgp_id      -- the security group identifier.
# +port        -- the TCP port.
# +protocol    -- the IP protocol name (tcp , udp , icmp , icmpv6), default is 
#                 tcp.
# +from_sgp_id -- the security group identifier representing the origin of the
#                 traffic. 
# Returns:      
#  None
#===============================================================================
function allow_access_from_security_group()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r sgp_id="${1}"
   local -r port="${2}"
   local -r protocol="${3}"
   local -r from_sgp_id="${4}" 

   aws ec2 authorize-security-group-ingress \
       --group-id "${sgp_id}" \
       --protocol "${protocol}" \
       --port "${port}" \
       --source-group "${from_sgp_id}" 

   exit_code=$?

   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: allowing access from security group.'
   fi  
 
   return "${exit_code}"
}

#===============================================================================
# Verifies if a security group grants access from a specific CIDR or Security 
# Group.  
#
# Globals:
#  None
# Arguments:
# +sgp_id   -- the security group identifier.
# +port     -- the TCP port.
# +protocol -- the IP protocol name (tcp , udp , icmp). 
# +from     -- the source CIDR or security group ID.
# Returns:      
#  true/false in the __RESULT variable.
#===============================================================================
function check_access_is_granted()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT='false'
   local exit_code=0
   local -r sgp_id="${1}"
   local -r port="${2}"
   local -r protocol="${3}"
   local -r from="${4}"
   local rule=''
   local cidr=''
   local group=''
   
   rule="$(aws ec2 describe-security-groups --group-id "${sgp_id}" --query "SecurityGroups[].IpPermissions[]" | \
      jq --arg fromPort "${port}" --arg toPort "${port}" --arg protocol "${protocol}" -c '.[] | 
         select(.FromPort | contains($fromPort|tonumber)) | 
         select(.ToPort | contains($toPort|tonumber)) | 
         select(.IpProtocol | contains($protocol))')"
        
   if [[ -z "${rule}" ]]
   then
      return 0   
   fi
   
   cidr="$(echo ${rule} | \
      jq --arg from "${from}" -c '. | 
         select(.IpRanges[].CidrIp | contains($from))')"
         
   if [[ -n "${cidr}" ]]
   then
      __RESULT='true' 
   fi
   
   group="$(echo ${rule} | \
      jq --arg from "${from}" -c '. | 
         select(.UserIdGroupPairs[].GroupId | contains($from))')"
   
   if [[ -n "${group}" ]]
   then
      __RESULT='true'  
   fi
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: allowing access from CIDR.'
   fi  
 
   return "${exit_code}"
}

#===============================================================================
# Revokes access to the traffic incoming from another security group.  
#
# Globals:
#  None
# Arguments:
# +sgp_id      -- the security group identifier.
# +port        -- the TCP port.
# +protocol    -- the IP protocol name (tcp , udp , icmp , icmpv6), default is 
#                 tcp. 
# +from_sgp_id -- the security group identifier representing the origin of the
#                 traffic. 
# Returns:      
#  none.
#===============================================================================
function revoke_access_from_security_group()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r sgp_id="${1}"
   local -r port="${2}"
   local -r protocol="${3}"
   local -r from_sgp_id="${4}"   

   aws ec2 revoke-security-group-ingress \
       --group-id "${sgp_id}" \
       --protocol "${protocol}" \
       --port "${port}" \
       --source-group "${from_sgp_id}" 

   exit_code=$?

   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: revoking access from security group.'
   fi  
 
   return "${exit_code}"
}

#===============================================================================
# Revokes access to the traffic incoming from a specific CIDR block.  
#
# Globals:
#  None
# Arguments:
# +sgp_id    -- the security group identifier.
# +port      -- the TCP port
# +protocol  -- the IP protocol name (tcp , udp , icmp , icmpv6), default is tcp. 
# +from_cidr -- the CIDR block representing the origin of the traffic.
# Returns:      
#  none.
#===============================================================================
function revoke_access_from_cidr()
{
   if [[ $# -lt 4 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r sgp_id="${1}"
   local -r port="${2}"
   local -r protocol="${3}"
   local -r from_cidr="${4}"
        
   aws ec2 revoke-security-group-ingress \
       --group-id "${sgp_id}" \
       --protocol "${protocol}" \
       --port "${port}" \
       --cidr "${from_cidr}" 
       
   exit_code=$?

   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: revoking access from CIDR.'
   fi  
 
   return "${exit_code}"
}

#===============================================================================
# Returns an instance's status.
#
# Globals:
#  None
# Arguments:
# +instance_nm -- the instance name.
# Returns:      
#  the status of the instance in the global __RESULT variable.  
#===============================================================================
function get_instance_state()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r instance_nm="${1}"
   local instance_st=''
  
   instance_st="$(aws ec2 describe-instances \
       --filters Name=tag-key,Values='Name' \
       --filters Name=tag-value,Values="${instance_nm}" \
       --query 'Reservations[*].Instances[*].State.Name' \
       --output text)"

   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: getting instance state.'
      return "${exit_code}"
   fi 

   __RESULT="${instance_st}"
   
   return "${exit_code}"
}

#===============================================================================
# Returns the public IP address associated to an instance.
#
# Globals:
#  None
# Arguments:
# +instance_nm -- the instance name.
# Returns:      
#  the instance public address in the __RESULT global variable.
#===============================================================================
function get_public_ip_address_associated_with_instance()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r instance_nm="${1}"
   local instance_ip=''
  
   instance_ip="$(aws ec2 describe-instances \
       --filters Name=tag-key,Values=Name \
       --filters Name=tag-value,Values="${instance_nm}" \
       --query 'Reservations[*].Instances[*].PublicIpAddress' \
       --output text )"

   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: getting public IP address associated with the instance.'
      return "${exit_code}"
   fi 

   __RESULT="${instance_ip}"
   
   return "${exit_code}"
}

#===============================================================================
# Returns the private IP address associated to an instance.
#
# Globals:
#  None
# Arguments:
# +instance_nm -- the instance name.
# Returns:      
#  the instance private address in the __RESULT global variable.
#===============================================================================
function get_private_ip_address_associated_with_instance()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r instance_nm="${1}"
   local instance_ip=''
  
   instance_ip="$(aws ec2 describe-instances \
       --filters Name=tag-key,Values=Name \
       --filters Name=tag-value,Values="${instance_nm}" \
       --query 'Reservations[*].Instances[*].PrivateIpAddress' \
       --output text )"

   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: getting private IP address associated with the instance.'
      return "${exit_code}"
   fi 

   __RESULT="${instance_ip}"
   
   return "${exit_code}"
}

#===============================================================================
# Returns the instance identifier.
#
# Globals:
#  None
# Arguments:
# +instance_nm -- the instance name.
# Returns:      
#  the instance identifier in the global __RESULT variable. 
#===============================================================================
function get_instance_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r instance_nm="${1}"
   local instance_id=''

   instance_id="$(aws ec2 describe-instances \
       --filters Name=tag-key,Values=Name \
       --filters Name=tag-value,Values="${instance_nm}" \
       --query 'Reservations[*].Instances[*].InstanceId' \
       --output text)"
       
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: getting instance ID.'
      return "${exit_code}"
   fi 

   __RESULT="${instance_id}"
   
   return "${exit_code}"
}

#===============================================================================
# Runs an instance and associates a public IP address to it.
# Globals:
#  None
# Arguments:
# +instance_nm     -- name assigned to the instance.
# +sgp_id          -- security group identifier.
# +subnet_id       -- subnet identifier.
# +private_ip      -- private IP address assigned to the instance.
# +image_id        -- identifier of the image from which the instance is derived.
# +cloud_init_file -- Cloud Init configuration file.
# Returns:      
#  none.   
#===============================================================================
function run_instance()
{
   if [[ $# -lt 6 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   local exit_code=0
   local -r instance_nm="${1}"
   local -r sgp_id="${2}"
   local -r subnet_id="${3}"
   local -r private_ip="${4}"
   local -r image_id="${5}"
   local -r cloud_init_file="${6}"
   local instance_id=''
     
   instance_id="$(aws ec2 run-instances \
       --image-id "${image_id}" \
       --security-group-ids "${sgp_id}" \
       --instance-type 't2.micro' \
       --placement "AvailabilityZone=${DTC_AZ_1},Tenancy=default" \
       --subnet-id "${subnet_id}" \
       --private-ip-address "${private_ip}" \
       --associate-public-ip-address \
       --block-device-mapping 'DeviceName=/dev/xvda,Ebs={DeleteOnTermination=true,VolumeSize=10}' \
       --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${instance_nm}}]" \
       --user-data file://"${cloud_init_file}" \
       --output text \
       --query 'Instances[*].InstanceId')"
       
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: running Admin instance.'
      return "${exit_code}"
   fi    
   
   aws ec2 wait instance-status-ok --instance-ids "${instance_id}"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: waiting for Admin instance.'
   fi   
   
   return "${exit_code}"
}

#===============================================================================
# Stops the instance and waits for it to stop.
#
# Globals:
#  None
# Arguments:
# +instance_id -- the instance identifier.
# Returns:      
#  None
#===============================================================================
function stop_instance()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r instance_id="${1}"

   aws ec2 stop-instances --instance-ids "${instance_id}" 
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: stopping instance.'
      return "${exit_code}"
   fi   
 
   aws ec2 wait instance-stopped --instance-ids "${instance_id}" 
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: waiting for instance.'
   fi 

   return "${exit_code}"
}

#===============================================================================
# Deletes the Instance. 
# Terminated Instances remain visible after termination for approximately one 
# hour. Any attached EBS volumes with the DeleteOnTermination block device 
# mapping parameter set to true are automatically deleted.
#
# Globals:
#  None
# Arguments:
# +instance_id     -- the instance identifier.
# +wait_terminated -- if passed and equal to 'and_wait, the function wait until
#                     the instance is in termitanted state.
# Returns:      
#  None
#===============================================================================
function delete_instance()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r instance_id="${1}"
   local wait_terminated=''
   
   if [[ $# -eq 2 ]]
   then
      wait_terminated="${2}"
   fi

   aws ec2 terminate-instances --instance-ids "${instance_id}"
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: terminating instance.'
      return "${exit_code}" 
   fi 

   if [[ 'and_wait' == "${wait_terminated}" ]]
   then
      aws ec2 wait instance-terminated --instance-ids "${instance_id}"
      
      exit_code=$?
   
      if [[ 0 -ne "${exit_code}" ]]
      then
         echo 'ERROR: waiting for instance.'
         return "${exit_code}" 
      fi 
   fi
   
   return "${exit_code}"
}

#===============================================================================
# Checks if the specified EC2 instance has an IAM instance profile associated.
#
# Globals:
#  None
# Arguments:
# +instance_nm -- the instance name.
# +instance_id -- the instance ID.
# +profile_nm  -- the IAM instance profile name.
# Returns:      
#  true or false value in the __RESULT global variable.  
#===============================================================================
function check_instance_has_instance_profile_associated()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi 
   
   __RESULT=''
   local exit_code=0
   local -r instance_nm="${1}"
   local -r profile_nm="${2}"
   local instance_id=''
   local profile_id=''
   local association_id=''
   local associated='false'
   
   __get_association_id "${instance_nm}" "${profile_nm}"

   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving the association ID.' 
      return "${exit_code}"
   fi
   
   association_id="${__RESULT}"
   __RESULT=''
   
   if [[ -n "${association_id}" ]]
   then
      associated='true' 
   fi
       
   __RESULT="${associated}"

   return "${exit_code}" 
}

#===============================================================================
# Associates the specified instance profile to an EC2 instance.
#
# Globals:
#  None
# Arguments:
# +instance_nm -- the instance name.
# +profile_nm  -- the IAM instance profile name.
# Returns:      
#  none.  
#===============================================================================
function associate_instance_profile_to_instance()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi 
   
   __RESULT=''
   local exit_code=0
   local -r instance_nm="${1}"
   local -r profile_nm="${2}"
   local instance_id=''
   
   get_instance_id "${instance_nm}"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving instance ID.' 
      return "${exit_code}"
   fi
   
   instance_id="${__RESULT}"
   __RESULT=''
   
   if [[ -z "${instance_id}" ]]
   then
      echo 'ERROR: EC2 instance not found.'
      return 1
   fi
   
   aws ec2 associate-iam-instance-profile --iam-instance-profile Name="${profile_nm}" \
      --instance-id "${instance_id}"    
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: associating instance profile to EC2 instance.'
   fi
   
   return "${exit_code}" 
}

#===============================================================================
# Associates the specified instance profile to an EC2 instance.
#
# Globals:
#  None
# Arguments:
# +instance_nm -- the instance name.
# +profile_nm  -- the IAM instance profile name.
# Returns:      
#  none.  
#===============================================================================
function associate_instance_profile_to_instance_and_wait()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi 
   
   __RESULT=''
   local exit_code=0
   local -r instance_nm="${1}"
   local -r profile_nm="${2}"
   local instance_id=''
   
   associate_instance_profile_to_instance "${instance_nm}" "${profile_nm}" ||
   {
      wait 30
      associate_instance_profile_to_instance "${instance_nm}" "${profile_nm}" ||
      {
         echo 'ERROR: associating instance profile to the instance.'
         exit 1
      }
   }
   
   return "${exit_code}" 
}

#===============================================================================
# Disassociate the specified instance profile to an EC2 instance.
#
# Globals:
#  None
# Arguments:
# +instance_nm -- the instance name.
# +profile_id  -- the IAM instance profile ID.
# Returns:      
#  none.  
#===============================================================================
function disassociate_instance_profile_from_instance()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi 
   
   __RESULT=''
   local exit_code=0
   local -r instance_nm="${1}"
   local -r profile_id="${2}"
   local instance_id=''
   local association_id=''
   
   __get_association_id "${instance_nm}" "${profile_id}"
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving the association ID.' 
      return "${exit_code}"
   fi
   
   association_id="${__RESULT}"
   __RESULT=''
   
   if [[ -z "${association_id}" ]]
   then
      echo 'ERROR: association ID not found.'
      return 1
   fi
   
   aws ec2 disassociate-iam-instance-profile --association-id "${association_id}"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: disassociating instance profile to EC2 instance.'
   fi
   
   return "${exit_code}" 
}

#===============================================================================
# Returns the association ID of an association in state 'associated' between
# an instance profile and an EC2 instance.
#
# Globals:
#  None
# Arguments:
# +instance_nm -- the instance name.
# +profile_id  -- the IAM instance profile ID.
# Returns:      
#  the association ID in the __RESULT global variable.  
#===============================================================================
function __get_association_id()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi 
   
   __RESULT=''
   local exit_code=0
   local -r instance_nm="${1}"
   local -r profile_id="${2}"
   local instance_id=''
   local association_id=''
   
   get_instance_id "${instance_nm}"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving instance ID.' 
      return "${exit_code}"
   fi
   
   instance_id="${__RESULT}"
   __RESULT=''
   
   if [[ -z "${instance_id}" ]]
   then
      echo 'ERROR: EC2 instance not found.'
      return 1
   fi
   
   association_id="$(aws ec2 describe-iam-instance-profile-associations \
       --query "IamInstanceProfileAssociations[? InstanceId == '${instance_id}' && IamInstanceProfile.Id == '${profile_id}' ].AssociationId" \
       --output text)"
  
   exit_code=$?

   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving the association ID.' 
      return "${exit_code}"
   fi
   
   __RESULT="${association_id}"
   
   return "${exit_code}"
}

#===============================================================================
# Creates an image from an Amazon EBS-backed instance and waits until the image
# is ready.
# Globals:
#  None
# Arguments:
# +instance_id -- the instance identifier.
# +img_nm      -- the image name.
# +img_desc    -- the image description.
# Returns:      
#  none.    
#===============================================================================
function create_image()
{
   if [[ $# -lt 3 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r instance_id="${1}"
   local -r img_nm="${2}"
   local -r img_desc="${3}"
   local img_id=''
   
   img_id="$(aws ec2 create-image \
        --instance-id "${instance_id}" \
        --name "${img_nm}" \
        --description "${img_desc}" \
        --query 'ImageId' \
        --output text)" 
  
   exit_code=$?

   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: creating imaged.' 
      return "${exit_code}"
   fi   
   
   aws ec2 wait image-available --image-ids "${img_id}"

   exit_code=$?

   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: waiting for image.' 
   fi
   
   return "${exit_code}" 
}

#===============================================================================
# Returns an images's identifier.
# Globals:
#  None
# Arguments:
# +img_nm -- the image name.
# Returns:      
#  the Image identifier int the global __RESULT variable.
#===============================================================================
function get_image_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r img_nm="${1}"
   local img_id=''

   img_id="$(aws ec2 describe-images \
        --filters Name=name,Values="${img_nm}" \
        --query 'Images[*].ImageId' \
        --output text)"
  
   exit_code=$?

   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving the imaged ID.' 
      return "${exit_code}"
   fi
   
   __RESULT="${img_id}"
   
   return "${exit_code}"
}

#===============================================================================
# Returns an images's state.
# Globals:
#  None
# Arguments:
# +img_nm -- the image name.
# Returns:      
#  the Image state in the global __RESULT variable.
#===============================================================================
function get_image_state()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r img_nm="${1}"
   local img_st=''

   img_st="$(aws ec2 describe-images \
        --filters Name=name,Values="${img_nm}" \
        --query 'Images[*].State' \
        --output text)"
  
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: getting image state.'
      return "${exit_code}"
   fi 

   __RESULT="${img_st}"
   
   return "${exit_code}"
}

#===============================================================================
# Returns the list of an image's snapshot identifiers as a string of IDs
# separated by space. 
#
# Globals:
#  None
# Arguments:
# +img_nm -- the image name.
# Returns:      
#  the list of Image Snapshot identifiers in the global __RESULT variable.
#===============================================================================
function get_image_snapshot_ids()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r img_nm="${1}"

   # AWS CLI provides built-in JSON-based output filtering capabilities with the --query option,
   # a JMESPATH expression is used as a filter. 
   local img_snapshot_ids=''

   img_snapshot_ids="$(aws ec2 describe-images \
       --filters Name=name,Values="${img_nm}" \
       --query 'Images[*].BlockDeviceMappings[*].Ebs.SnapshotId' \
       --output text)"
  
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: getting image snapshot IDs.'
      return "${exit_code}"
   fi 

   __RESULT="${img_snapshot_ids}"
   
   return "${exit_code}"
}

#===============================================================================
# Deletes (deregisters) the specified Image.
#
# Globals:
#  None
# Arguments:
# +img_id  -- the Image identifier.
# Returns:      
#  None
#========================================================
function delete_image()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r img_id="${1}"

   aws ec2 deregister-image --image-id "${img_id}"

   exit_code=$?

   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting image.' 
   fi
   
   return "${exit_code}" 
}

#===============================================================================
# Deletes a Snapshot by identifier. the Image must be 
# deregisterd first.
#
# Globals:
#  None
# Arguments:
# +img_snapshot_id -- the Image Snapshot identifier.
# Returns:      
#  None
#========================================================
function delete_image_snapshot()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r img_snapshot_id="${1}"

   aws ec2 delete-snapshot --snapshot-id "${img_snapshot_id}" 
   
   exit_code=$?

   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting image snapshot.' 
   fi
   
   return "${exit_code}" 
}

#===============================================================================
# Returns the public IP address allocation identifier. If the address is not 
# allocated with your account, a blanc string is returned.
#
# Globals:
#  None
# Arguments:
# +eip -- the Elastic IP Public address.
# Returns:      
#  the allocation identifier in the global __RESULT variable.
#===============================================================================
function get_allocation_id()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r eip="${1}"
   local allocation_id=''
          
   allocation_id="$(aws ec2 describe-addresses \
       --filter Name=public-ip,Values="${eip}" \
       --query 'Addresses[*].AllocationId' \
       --output text)"

   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: getting allocation ID.'
      return "${exit_code}"
   fi 

   __RESULT="${allocation_id}"
   
   return "${exit_code}"
}

#===============================================================================
# Returns a list of allocation identifiers associated your account.
# The list is a string where each identifier is separated by a space.
#
# Globals:
#  None
# Arguments:
#  None
# Returns:      
#  A list of allocation identifiers in the __RESULT global variable.
#===============================================================================
function get_all_allocation_ids()
{
   __RESULT=''
   local exit_code=0
   local allocation_ids=''
          
   allocation_ids="$(aws ec2 describe-addresses \
       --query 'Addresses[*].AllocationId' \
       --output text)"

   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: getting allocation IDs.'
      return "${exit_code}"
   fi 

   __RESULT="${allocation_ids}"
   
   return "${exit_code}"
}

#===============================================================================
# Returns an IP Address allocated to your AWS account not associated with an 
# instance. If no Address if found, an empty string is returned.
#
# Globals:
#  None
# Arguments:
#  None
# Returns:      
#  An unused public IP Address in your account in the global __RESULT variable.
#===============================================================================
function get_unused_public_ip_address()
{
   __RESULT=''
   local exit_code=0
   local eip=''
   local eip_list=''
   
   eip_list="$(aws ec2 describe-addresses \
       --query 'Addresses[?InstanceId == null].PublicIp' \
       --output text)"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving unused IP address.' 
      return "${exit_code}"
   fi
            
   if [[ -n "${eip_list}" ]]
   then
       #Getting the first
       eip="$(echo "${eip_list}" | awk '{print $1}')"
   fi
            
   __RESULT="${eip}"
   
   return "${exit_code}"
}

#===============================================================================
# Allocates an Elastic IP address to your AWS account. After you allocate the 
# Elastic IP address you can associate it with an instance or network interface.
#
# Globals:
#  None
# Arguments:
#  None
# Returns:      
#  the IP address allocated to your account in the __RESULT global variable.  
#===============================================================================
function allocate_public_ip_address()
{
   __RESULT=''
   local exit_code=0
   local eip=''
  
   eip="$(aws ec2 allocate-address \
       --query 'PublicIp' \
       --output text)"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: allocating IP address.' 
      return "${exit_code}"
   fi

   __RESULT="${eip}"
   
   return "${exit_code}"
}

#===============================================================================
# Releases an Elastic IP address allocated with your account.
# Releasing an Elastic IP address automatically disassociates it from the 
# instance. Be sure to update your DNS records and any servers or devices that 
# communicate with the address.
#
# Globals:
#  None
# Arguments:
# +allocation_id -- allocation identifier.
# Returns:      
#  None 
#===============================================================================
function release_public_ip_address()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r allocation_id="${1}"

   aws ec2 release-address --allocation-id "${allocation_id}"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]] 
   then
      echo 'ERROR: releasing public IP address.'
   fi

   return "${exit_code}"
}

#===============================================================================
# Releases a list of Elastic IP addresses allocated with your account.
# Releasing an Elastic IP address automatically disassociates it from the 
# instance. Be sure to update your DNS records and any servers or devices that 
# communicate with the address.
#
# Globals:
#  None
# Arguments:
#  +allocation_ids -- the list of allocation identifiers.
# Returns:      
#  None 
#===============================================================================
function release_all_public_ip_addresses()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   local exit_code=0
   local -r allocation_ids="${1}"
          
   for id in ${allocation_ids}
   do
      aws ec2 release-address --allocation-id "${id}" 
      exit_code=$?
   
      if [[ 0 -ne "${exit_code}" ]] 
      then
         echo 'ERROR: releasing public IP address.'
         return "${exit_code}"
      fi      
   done

   return "${exit_code}"
}

#===============================================================================
# Checks if Amazon EC2 stores a public key.
#
# Globals:
#  None
# Arguments:
#  +key_nm -- a unique EC2 name for the key pair.
# Returns:      
#  true/false in the global __RESULT variable. 
#===============================================================================
function check_aws_public_key_exists()
{
   if [[ $# -lt 1 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   __RESULT=''
   local exit_code=0
   local -r key_nm="${1}"
   local exists='false'
   local key=''
   
   key=$(aws ec2 describe-key-pairs --query "KeyPairs[? KeyName=='${key_nm}'].KeyFingerprint" --output text)
  
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: retrieving key pair name.'
      return "${exit_code}"
   fi
   
   if [[ -n "${key}" ]]
   then
      exists='true'
   fi
   
   __RESULT="${exists}"
   
   return "${exit_code}"
}

#===============================================================================
# Creates a 2048-bit RSA key pair with the specified name. 
# Amazon EC2 stores the public key and displays the private key for you to save 
# to a file.  
# The private key is returned as an unencrypted PEM encoded PKCS#1 private key. 
# If a key with the specified name already exists, Amazon EC2 returns an error.
#
# Globals:
#  None
# Arguments:
#  +key_nm      -- a unique EC2 name for the key pair.
#  +keypair_dir -- the local directory where the private key is saved.
# Returns:      
#  none. 
#===============================================================================
function generate_aws_keypair()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi
   
   local exit_code=0
   local -r key_nm="${1}"
   local -r keypair_dir="${2}"
   local key="${keypair_dir}"/"${key_nm}"
   
   aws ec2 create-key-pair --key-name "${key_nm}" --query 'KeyMaterial' \
      --output text > "${key}"
      
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: creating the key pair.'
      return "${exit_code}"
   fi
   
   chmod 600 "${key}"
   exit_code=$?
   
   return "${exit_code}"
}

#===============================================================================
# Deletes the public key in AWS EC2 and the local private key file.
#
# Globals:
#  None
# Arguments:
#  +key_nm   -- a unique EC2 name for the key pair.
#  +key_file -- the local private key file.
# Returns:      
#  None
#===============================================================================
function delete_aws_keypair()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local exit_code=0
   local -r key_nm="${1}"
   local -r keypair_dir="${2}"
   local key="${keypair_dir}"/"${key_nm}"
   
   # Delete the key on AWS EC2.
   aws ec2 delete-key-pair --key-name "${key_nm}"
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting the key pair in EC2.'
      return "${exit_code}"
   fi

   # Delete the local private-key.
   rm -f "${key:?}"
   rm -f "${key:?}.*"
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: deleting the local key pair file.'
   fi

   return "${exit_code}"
}

#===============================================================================
# Imports the public key in EC2 from an RSA key pair that you created with a 
# third-party tool.
#
# Globals:
#  None
# Arguments:
#  +key_nm       -- a unique EC2 name for the key pair.
#  +key_material -- the public key material.
# Returns:      
#  None
#===============================================================================
function upload_public_key_to_ec2()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 1
   fi

   local exit_code=0
   local -r key_nm="${1}"
   local -r key_material="${2}"
   
   aws ec2 import-key-pair --key-name "${key_nm}" \
       --public-key-material "${key_material}"
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: importing public key to EC2.'
   fi

   return "${exit_code}"
}
