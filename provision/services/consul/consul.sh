#!/bin/bash

# shellcheck disable=SC1091

########################################################################################################################
# Consul is a datacenter runtime that provides service discovery, configuration, and orchestration.
# By default, Consul allows connections to the following ports only from the loopback interface (127.0.0.1). 
#  8500: handles HTTP API requests from clients
#  8400: handles requests from CLI
#  8600: answers DNS queries
#
#   dig @0.0.0.0 -p 8600 node1.node.consul
#   curl localhost:8500/v1/catalog/nodes
#
########################################################################################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

SCRIPTS_DIR='SEDscripts_dirSED'
INSTANCE_EIP_ADDRESS='SEDinstance_eip_addressSED'
INSTANCE_PRIVATE_ADDRESS='SEDinstance_private_addressSED'
CONSUL_HTTP_PORT='SEDconsul_http_portSED'
CONSUL_DNS_PORT='SEDconsul_dns_portSED'

yum update -y && yum install -y jq

####
echo 'Installing Consul ...'
####

yum install -y yum-utils
yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
yum -y install consul
mkdir -p /etc/consul.d/scripts
mkdir -p /var/consul
consul_key="$(consul keygen)"
cd "${SCRIPTS_DIR}"
jq --arg key "${consul_key}" '.encrypt = $key' consul-server.json > /etc/consul.d/consul-server.json
cp consul.service /etc/systemd/system/

echo 'Consul installed.'

systemctl daemon-reload
systemctl restart consul
systemctl status consul 
consul version

echo 'Consul server started.'     

consul members

yum remove -y jq

node_name="$(consul members |awk -v address="${INSTANCE_PRIVATE_ADDRESS}" '$2~address {print $1}')"

echo
echo "http://${INSTANCE_EIP_ADDRESS}:${CONSUL_HTTP_PORT}/ui"
echo "dig @${INSTANCE_EIP_ADDRESS} -p ${CONSUL_DNS_PORT} ${node_name}.node.consul"
echo
