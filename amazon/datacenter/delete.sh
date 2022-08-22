#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

###
STEP 'Data center'
###

get_datacenter_id "${DTC_NM}"
dtc_id="${__RESULT}"

if [[ -z "${dtc_id}" ]]
then
   echo '* WARN: data center not found.'
else
   echo "* data center ID: ${dtc_id}"
fi

get_internet_gateway_id "${DTC_INTERNET_GATEWAY_NM}"
internet_gate_id="${__RESULT}"
internet_gate_attach_status=''

if [[ -z "${internet_gate_id}" ]]
then
   echo '* WARN: internet gateway not found.'
else
   get_internet_gateway_attachment_status "${DTC_INTERNET_GATEWAY_NM}" "${dtc_id}"
   internet_gate_attach_status="${__RESULT}"
   
   if [[ -n "${internet_gate_attach_status}" ]]
   then
      echo "* internet gateway ID: ${internet_gate_id} (${internet_gate_attach_status})."
   else
      echo "* internet gateway ID: ${internet_gate_id}."
   fi
fi

get_subnet_id "${DTC_SUBNET_MAIN_NM}"
main_subnet_id="${__RESULT}"

if [[ -z "${main_subnet_id}" ]]
then
   echo '* WARN: main subnet not found.'
else
   echo "* main subnet ID: ${main_subnet_id}."
fi

get_subnet_id "${DTC_SUBNET_BACKUP_NM}"
backup_subnet_id="${__RESULT}"

if [[ -z "${backup_subnet_id}" ]]
then
   echo '* WARN: backup subnet not found.'
else
   echo "* backup subnet ID: ${backup_subnet_id}."
fi

get_route_table_id "${DTC_ROUTE_TABLE_NM}"
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

if [[ -n "${internet_gate_id}" ]]
then
   if [ -n "${dtc_id}" ]
   then     
      if [ -n "${internet_gate_attach_status}" ]
      then
         aws ec2 detach-internet-gateway --internet-gateway-id  "${internet_gate_id}" --vpc-id "${dtc_id}"
         
         echo 'Internet gateway detached from VPC.'
      fi
   fi
    
   delete_internet_gateway "${internet_gate_id}"
   
   echo 'Internet gateway deleted.'
fi

#
# Main Subnet
#	

if [[ -n "${main_subnet_id}" ]]
then
   delete_subnet "${main_subnet_id}"
   
   echo 'Main subnet deleted.'
fi

# 
# Backup subnet 
# 

if [[ -n "${backup_subnet_id}" ]]
then
   delete_subnet "${backup_subnet_id}"
   
   echo 'Backup subnet deleted.'
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


