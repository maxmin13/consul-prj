#!/bin/bash
   
set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#
STEP 'Account'
#

ec2_get_all_allocation_ids
allocation_ids="${__RESULT}"
if [[ -z "${allocation_ids}" ]]
then
   echo '* WARN: public IP addresses not found.'
else
   echo "* public IP addresses allocation IDs: ${allocation_ids}."
fi

if [[ -n "${allocation_ids}" ]]
then
   ec2_release_all_public_ip_addresses "${allocation_ids}"
   
   echo 'Released all allocated public IP addresses.'
fi

