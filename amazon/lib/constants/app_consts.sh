#!/usr/bin/bash

# shellcheck disable=SC2034

EMAIL='minardi.massimiliano@libero.it'

## *********** ##
## Data center ##
## *********** ##

DTC_NM='datacenter'
DTC_CDIR='10.0.0.0/16' # the first four adresses are reserved by AWS.
DTC_INTERNET_GATEWAY_NM='internet-gateway'
DTC_REGION='eu-west-1'
DTC_AZ_1='eu-west-1a'
DTC_SUBNET_MAIN_NM='main-subnet'
DTC_SUBNET_MAIN_CIDR='10.0.10.0/24'
DTC_SUBNET_MAIN_INTERNAL_GATEWAY_IP='10.0.10.1'
DTC_ROUTE_TABLE_NM='route-table'

## ************ ##
## Permissions  ##
## ************ ##

ECR_POLICY_NM='AmazonEC2ContainerRegistryFullAccess'
SECRETSMANAGER_POLICY_NM="AmazonSecretsManagerAccess"

## ************** ##
##   AWS common   ##
## ************** ##

AWS_BASE_IMG_ID='ami-058b1b7fe545997ae' 
USER_NM='awsadmin'
USER_PWD='awsadmin'

## **************** ##
## AWS Shared image ##
## **************** ##

SHARED_INST_NM='shared-box'
SHARED_INST_HOSTNAME='shared.maxmin.it'
SHARED_INST_PRIVATE_IP='10.0.10.5'
SHARED_INST_SSH_PORT='38142'
SHARED_INST_KEY_PAIR_NM='shared-key'
SHARED_INST_SEC_GRP_NM='shared-box-sgp'
SHARED_IMG_NM='shared-image'
SHARED_IMG_DESC='Linux secured Image'

## **************** ##
##  AWS Admin box   ##
## **************** ##

ADMIN_INST_NM='admin-box'
ADMIN_INST_PRIVATE_IP='10.0.10.9'
ADMIN_CONSUL_SERVER_RPC_PORT='8300'
ADMIN_CONSUL_SERVER_SERF_LAN_PORT='8301'
ADMIN_CONSUL_SERVER_SERF_WAN_PORT='8302'
ADMIN_CONSUL_SERVER_HTTP_PORT='8500' 
ADMIN_CONSUL_SERVER_DNS_PORT='8600' 
ADMIN_INST_HOSTNAME='admin.maxmin.it'
ADMIN_INST_SEC_GRP_NM='admin-sgp'
ADMIN_INST_KEY_PAIR_NM='admin-key'
ADMIN_INST_PROFILE_NM='AdminInstanceProfile'
ADMIN_AWS_ROLE_NM='AdminAWSrole'

## **************** ##
## AWS Jenkins box  ##
## **************** ##

JENKINS_INST_NM='jenkins-box'
JENKINS_INST_PRIVATE_IP='10.0.10.10'
JENKINS_HTTP_PORT='80'
JENKINS_INST_HOSTNAME='jenkins.maxmin.it'
JENKINS_INST_SEC_GRP_NM='jenkins-sgp'
JENKINS_INST_KEY_PAIR_NM='jenkins-key'
JENKINS_INST_PROFILE_NM='JenkinsInstanceProfile'
JENKINS_AWS_ROLE_NM='JenkinsAWSrole'
JENKINS_INST_HOME_DIR='/var/jenkins_home'

## **************** ##
##  AWS Nginx box   ##
## **************** ##

NGINX_INST_NM='nginx-box'
NGINX_INST_PRIVATE_IP='10.0.10.20'
NGINX_HTTP_PORT='80'
NGINX_INST_HOSTNAME='nginx.maxmin.it'
NGINX_INST_SEC_GRP_NM='nginx-sgp'
NGINX_INST_KEY_PAIR_NM='nginx-key'
NGINX_INST_PROFILE_NM='NginxInstanceProfile'
NGINX_AWS_ROLE_NM='NginxAWSrole'
NGINX_INST_WEBAPPS_DIR='/opt/nginx/webapps'

## **************** ##
## AWS Redis db box ##
## **************** ##

REDIS_INST_NM='redis-box'
REDIS_INST_PRIVATE_IP='10.0.10.30'
REDIS_IP_PORT='6379'
REDIS_CONSUL_SERVER_RPC_PORT='8300'
REDIS_CONSUL_SERVER_SERF_LAN_PORT='8301'
REDIS_CONSUL_SERVER_SERF_WAN_PORT='8302'
REDIS_CONSUL_SERVER_HTTP_PORT='8500' 
REDIS_CONSUL_SERVER_DNS_PORT='8600'
REDIS_INST_HOSTNAME='redis.maxmin.it'
REDIS_INST_SEC_GRP_NM='redis-sgp'
REDIS_INST_KEY_PAIR_NM='redis-key'
REDIS_INST_PROFILE_NM='RedisInstanceProfile'
REDIS_AWS_ROLE_NM='RedisAWSrole' 

## **************** ##
## AWS Sinatra box  ##
## **************** ##

SINATRA_INST_NM='sinatra-box'
SINATRA_INST_PRIVATE_IP='10.0.10.33'
SINATRA_HTTP_PORT='4567'
SINATRA_INST_HOSTNAME='sinatra.maxmin.it'
SINATRA_INST_SEC_GRP_NM='sinatra-sgp'
SINATRA_INST_KEY_PAIR_NM='sinatra-key'
SINATRA_INST_PROFILE_NM='SinatraInstanceProfile'
SINATRA_AWS_ROLE_NM='SinatraAWSrole'

