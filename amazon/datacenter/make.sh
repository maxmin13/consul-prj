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

logfile_nm='datacenter.log'

###
STEP 'Data-center'
###

get_datacenter 'Name' 
dtc_nm="${__RESULT}"
get_datacenter_id "${dtc_nm}"
dtc_id="${__RESULT}"
get_datacenter 'Cidr' 
dtc_cidr="${__RESULT}"  

if [[ -n "${dtc_id}" ]]
then
   echo 'WARN: the data center has already been created.'
else
   ## Make a new VPC with a master 10.0.10.0/16 subnet
   create_datacenter "${dtc_nm}" "${dtc_cidr}" >> "${LOGS_DIR}"/"${logfile_nm}"
   get_datacenter_id "${dtc_nm}"
   dtc_id="${__RESULT}"
    
   echo 'Data center created.'
fi

#
# Internet gateway
#

get_datacenter 'Gateway' 
gateway_nm="${__RESULT}"
get_internet_gateway_id "${gateway_nm}"
gateway_id="${__RESULT}"

if [[ -n "${gateway_id}" ]]
then
   echo 'WARN: the internet gateway has already been created.'
else
   create_internet_gateway "${gateway_nm}" "${dtc_id}" >> "${LOGS_DIR}"/"${logfile_nm}"
   get_internet_gateway_id "${gateway_nm}"
   gateway_id="${__RESULT}"
	              
   echo 'Internet gateway created.' 
fi
  
## Check if the internet gateway is already attached to the VPC.
get_internet_gateway_attachment_status "${gateway_nm}" "${dtc_id}"
gateway_status="${__RESULT}"

if [[ 'available' != "${gateway_status}" ]]
then
   attach_internet_gateway "${gateway_id}" "${dtc_id}"
   
   echo 'The internet gateway has been attached to the Data Center.'	
fi

# 
# Route table
# 

get_datacenter 'RouteTable' 
rtb_nm="${__RESULT}"
get_route_table_id "${rtb_nm}"
rtb_id="${__RESULT}"
							
if [[ -n "${rtb_id}" ]]
then
   echo 'WARN: the route table has already been created.'
else
   create_route_table "${rtb_nm}" "${dtc_id}" >> "${LOGS_DIR}"/"${logfile_nm}"
   get_route_table_id "${rtb_nm}"
   rtb_id="${__RESULT}"
                   
   echo 'Created route table.'
fi

check_has_route "${rtb_id}" "${gateway_id}" '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
has_route="${__RESULT}"

if [[ 'false' == "${has_route}" ]]
then
   set_route "${rtb_id}" "${gateway_id}" '0.0.0.0/0' >> "${LOGS_DIR}"/"${logfile_nm}"
   
   echo 'Created route that points all traffic to the internet gateway.'
else
   echo 'WARN: route already created.'
fi

#
# Subnet
#

get_datacenter 'Subnet' 
subnet_nm="${__RESULT}"
get_subnet_id "${subnet_nm}"
subnet_id="${__RESULT}"

if [[ -n "${subnet_id}" ]]
then
   echo 'WARN: the subnet has already been created.'
else

   get_datacenter 'Az'
   az_nm="${__RESULT}"
   get_datacenter 'SubnetCidr' 
   subnet_cidr="${__RESULT}"
   
   create_subnet "${subnet_nm}" \
       "${subnet_cidr}" "${az_nm}" "${dtc_id}" "${rtb_id}" >> "${LOGS_DIR}"/"${logfile_nm}"
       
   get_subnet_id "${subnet_nm}"
   subnet_id="${__RESULT}"
   
   echo "The subnet has been created in the ${az_nm} availability zone and associated to the route table."    
fi

echo
echo 'Data center up and running.'
echo
