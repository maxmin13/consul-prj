#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

##
## Amazon Virtual Private Cloud (Amazon VPC) enables you to define a virtual networking environment in a private, 
## isolated section of the AWS cloud. Within this virtual private cloud (VPC), you can launch AWS resources such as 
## Load Balancers and EC2 instances. 
##

# Enforce parameter
if [ "$#" -lt 1 ]; then
  echo "USAGE: network_key"
  echo "EXAMPLE: net"
  echo "Only provided $# arguments"
  exit 1
fi

network_key="${1}"
logfile_nm='datacenter.log'

###
STEP 'Datacenter'
###

get_datacenter 'Name' 
dtc_nm="${__RESULT}"
ec2_get_datacenter_id "${dtc_nm}"
dtc_id="${__RESULT}"
get_datacenter 'Cidr' 
dtc_cidr="${__RESULT}"  

if [[ -n "${dtc_id}" ]]
then
   echo 'WARN: data center already created.'
else
   ## Make a new VPC with a 10.0.10.0/16 subnet
   ec2_create_datacenter "${dtc_nm}" "${dtc_cidr}" >> "${LOGS_DIR}"/"${logfile_nm}"
   ec2_get_datacenter_id "${dtc_nm}"
   dtc_id="${__RESULT}"
    
   echo 'Data center created.'
fi

#
# Internet gateway
#

get_datacenter 'Gateway' 
gateway_nm="${__RESULT}"
ec2_get_internet_gateway_id "${gateway_nm}"
gateway_id="${__RESULT}"

if [[ -n "${gateway_id}" ]]
then
   echo 'WARN: internet gateway already created.'
else
   ec2_create_internet_gateway "${gateway_nm}" "${dtc_id}" >> "${LOGS_DIR}"/"${logfile_nm}"
   ec2_get_internet_gateway_id "${gateway_nm}"
   gateway_id="${__RESULT}"
	              
   echo 'Internet gateway created.' 
fi
  
## Check if the internet gateway is already attached to the VPC.
ec2_get_internet_gateway_attachment_status "${gateway_nm}" "${dtc_id}"
gateway_status="${__RESULT}"

if [[ 'available' != "${gateway_status}" ]]
then
   ec2_attach_internet_gateway "${gateway_id}" "${dtc_id}"
   
   echo 'Internet gateway attached to the data center.'	
fi

# 
# Route table
# 

get_datacenter 'RouteTable' 
rtb_nm="${__RESULT}"
ec2_get_route_table_id "${rtb_nm}"
rtb_id="${__RESULT}"
							
if [[ -n "${rtb_id}" ]]
then
   echo 'WARN: route table already created.'
else
   ec2_create_route_table "${rtb_nm}" "${dtc_id}" >> "${LOGS_DIR}"/"${logfile_nm}"
   ec2_get_route_table_id "${rtb_nm}"
   rtb_id="${__RESULT}"
                   
   echo 'Route table created.'
fi

ec2_check_has_route "${rtb_id}" "${gateway_id}" '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
has_route="${__RESULT}"

if [[ 'false' == "${has_route}" ]]
then
   ec2_set_route "${rtb_id}" "${gateway_id}" '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   # Create a route that points all traffic to the internet gateway.
   echo 'Route created.'
else
   echo 'WARN: route already created.'
fi

#
# Subnet
#

get_datacenter_network "${network_key}" 'Name' 
subnet_nm="${__RESULT}"
ec2_get_subnet_id "${subnet_nm}"
subnet_id="${__RESULT}"

if [[ -n "${subnet_id}" ]]
then
   echo 'WARN: subnet already created.'
else
   get_datacenter 'Az'
   az_nm="${__RESULT}"
   get_datacenter_network "${network_key}" 'Cidr'
   subnet_cidr="${__RESULT}"

   ec2_create_subnet "${subnet_nm}" "${subnet_cidr}" "${az_nm}" "${dtc_id}" "${rtb_id}" >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo "Subnet created."    
fi

echo
echo 'Data center up and running.'
echo
