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

###
STEP 'Data center'
###

get_datacenter_name
dtc_nm="${__RESULT}"
get_datacenter_id "${dtc_nm}"
data_center_id="${__RESULT}"
get_datacenter_cidr
datacenter_cidr="${__RESULT}"  

if [[ -n "${data_center_id}" ]]
then
   echo 'WARN: the data center has already been created.'
else
   ## Make a new VPC with a master 10.0.10.0/16 subnet
   create_datacenter "${dtc_nm}" "${datacenter_cidr}" >> "${LOGS_DIR}"/datacenter.log
   get_datacenter_id "${dtc_nm}"
   data_center_id="${__RESULT}"
    
   echo 'Data center created.'
fi

#
# Internet gateway
#

get_internet_gateway_name
gateway_nm="${__RESULT}"
get_internet_gateway_id "${gateway_nm}"
internet_gate_id="${__RESULT}"

if [[ -n "${internet_gate_id}" ]]
then
   echo 'WARN: the internet gateway has already been created.'
else
   create_internet_gateway "${gateway_nm}" "${data_center_id}" >> "${LOGS_DIR}"/datacenter.log
   get_internet_gateway_id "${gateway_nm}"
   internet_gate_id="${__RESULT}"
	              
   echo 'Internet gateway created.' 
fi
  
## Check if the internet gateway is already attached to the VPC.
get_internet_gateway_attachment_status "${gateway_nm}" "${data_center_id}"
attach_status="${__RESULT}"

if [[ 'available' != "${attach_status}" ]]
then
   attach_internet_gateway "${internet_gate_id}" "${data_center_id}"
   
   echo 'The internet gateway has been attached to the Data Center.'	
fi

# 
# Route table
# 

get_route_table_name
route_table_nm="${__RESULT}"

get_route_table_id "${route_table_nm}"
route_table_id="${__RESULT}"
							
if [[ -n "${route_table_id}" ]]
then
   echo 'WARN: the route table has already been created.'
else
   create_route_table "${route_table_nm}" "${data_center_id}" >> "${LOGS_DIR}"/datacenter.log
   get_route_table_id "${route_table_nm}"
   route_table_id="${__RESULT}"
                   
   echo 'Created route table.'
fi

set_route "${route_table_id}" "${internet_gate_id}" '0.0.0.0/0' >> "${LOGS_DIR}"/datacenter.log

echo 'Created route that points all traffic to the internet gateway.'

#
# Main subnet
#

get_subnet_name
subnet_nm="${__RESULT}"
get_subnet_id "${subnet_nm}"
main_subnet_id="${__RESULT}"

if [[ -n "${main_subnet_id}" ]]
then
   echo 'WARN: the main subnet has already been created.'
else

   get_availability_zone_name
   az_nm="${__RESULT}"
   get_subnet_cidr
   subnet_cidr="${__RESULT}"
   
   create_subnet "${subnet_nm}" \
       "${subnet_cidr}" "${az_nm}" "${data_center_id}" "${route_table_id}" >> "${LOGS_DIR}"/datacenter.log
       
   get_subnet_id "${subnet_nm}"
   main_subnet_id="${__RESULT}"
   
   echo "The main subnet has been created in the ${az_nm} availability zone and associated to the route table."    
fi

echo
echo 'Data center up and running.'
echo
