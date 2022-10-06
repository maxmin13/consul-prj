#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###
STEP 'Data-center'
###

get_datacenter 'Name' 
dtc_nm="${__RESULT}"
get_datacenter_id "${dtc_nm}"
dtc_id="${__RESULT}"

if [[ -z "${dtc_id}" ]]
then
   echo '* WARN: data center not found.'
else
   echo "* data center ID: ${dtc_id}"
fi

get_datacenter 'Gateway' 
gateway_nm="${__RESULT}"
get_internet_gateway_id "${gateway_nm}"
gateway_id="${__RESULT}"
gateway_status=''

if [[ -z "${gateway_id}" ]]
then
   echo '* WARN: internet gateway not found.'
else
   get_internet_gateway_attachment_status "${gateway_nm}" "${dtc_id}"
   gateway_status="${__RESULT}"
   
   if [[ -n "${gateway_status}" ]]
   then
      echo "* internet gateway ID: ${gateway_id} (${gateway_status})."
   else
      echo "* internet gateway ID: ${gateway_id}."
   fi
fi

get_datacenter 'Subnet' 
subnet_nm="${__RESULT}"
get_subnet_id "${subnet_nm}"
subnet_id="${__RESULT}"

if [[ -z "${subnet_id}" ]]
then
   echo '* WARN: subnet not found.'
else
   echo "* subnet ID: ${subnet_id}."
fi

get_datacenter 'RouteTable' 
rtb_nm="${__RESULT}"
get_route_table_id "${rtb_nm}"
rtb_id="${__RESULT}"

if [[ -z "${rtb_id}" ]]
then
   echo '* WARN: route table not found.'
else
   echo "* route table ID: ${rtb_id}."
fi

echo

#
# Internet Gateway
#

if [[ -n "${gateway_id}" ]]
then
   if [ -n "${dtc_id}" ]
   then     
      if [ -n "${gateway_status}" ]
      then
         aws ec2 detach-internet-gateway --internet-gateway-id  "${gateway_id}" --vpc-id "${dtc_id}"
         
         echo 'Internet gateway detached from VPC.'
      fi
   fi
    
   delete_internet_gateway "${gateway_id}"
   
   echo 'Internet gateway deleted.'
fi

#
# Subnet
#	

if [[ -n "${subnet_id}" ]]
then
   delete_subnet "${subnet_id}"
   
   echo 'Subnet deleted.'
fi

#
# Route table
#

if [[ -n "${rtb_id}" ]]
then
   delete_route_table "${rtb_id}"
   
   echo 'Route table deleted.'
fi

## We can finally delete the VPC, all remaining assets are also deleted (eg route table, default security group..
## Tags are deleted automatically when associated resource dies.
                   
if [[ -n "${dtc_id}" ]]
then
   delete_datacenter "${dtc_id}" 
   
   echo 'Data center deleted.'
fi                     


