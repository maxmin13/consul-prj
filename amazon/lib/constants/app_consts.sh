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
DTC_AZ_2='eu-west-1b'
DTC_SUBNET_BACKUP_NM='backup-subnet'
DTC_SUBNET_BACKUP_CIDR='10.0.20.0/24'
DTC_SUBNET_BACKUP_INTERNAL_GATEWAY_IP='10.0.20.1'
DTC_SUBNET_BACKUP_RESERVED_IPS='10.0.20.1-10.0.20.29'
DTC_ROUTE_TABLE_NM='route-table'

## ************ ##
## Permissions  ##
## ************ ##

ADMIN_ROLE_NM='AdminECRrole'
NGINX_ROLE_NM='NginxECRrole'
JENKINS_ROLE_NM='JenkinsECRrole'
REDIS_ROLE_NM='RedisECRrole'
SINATRA_ROLE_NM='SinatraECRrole'
REGISTRY_POLICY_NM='AmazonEC2ContainerRegistryFullAccess'

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
## AWS Admin box  ##
## **************** ##

ADMIN_INST_NM='admin-box'
ADMIN_INST_PRIVATE_IP='10.0.10.9'
ADMIN_INST_HOSTNAME='admin.maxmin.it'
ADMIN_INST_SEC_GRP_NM='admin-sgp'
ADMIN_INST_KEY_PAIR_NM='admin-key'
ADMIN_INST_PROFILE_NM='MaxminAdminInstanceProfile'

## **************** ##
## AWS Jenkins box  ##
## **************** ##

JENKINS_INST_NM='jenkins-box2'
JENKINS_INST_PRIVATE_IP='10.0.10.10'
JENKINS_HTTP_PORT='80'
JENKINS_INST_HOSTNAME='jenkins.maxmin.it'
JENKINS_INST_SEC_GRP_NM='jenkins-sgp'
JENKINS_INST_KEY_PAIR_NM='jenkins-key'
JENKINS_INST_PROFILE_NM='MaxminJenkinsInstanceProfile'
JENKINS_INST_HOME_DIR='/var/jenkins_home'

## **************** ##
##  AWS Nginx box   ##
## **************** ##

NGINX_INST_NM='nginx-box2'
NGINX_INST_PRIVATE_IP='10.0.10.20'
NGINX_HTTP_PORT='80'
NGINX_INST_HOSTNAME='nginx.maxmin.it'
NGINX_INST_SEC_GRP_NM='nginx-sgp'
NGINX_INST_KEY_PAIR_NM='nginx-key'
NGINX_INST_PROFILE_NM='MaxminNginxInstanceProfile'
NGINX_INST_WEBAPPS_DIR='/opt/nginx/webapps'

## **************** ##
## AWS Redis db box ##
## **************** ##

REDIS_INST_NM='redis-box3'
REDIS_INST_PRIVATE_IP='10.0.10.30'
REDIS_IP_PORT='6379'
REDIS_INST_HOSTNAME='redis.maxmin.it'
REDIS_INST_SEC_GRP_NM='redis-sgp'
REDIS_INST_KEY_PAIR_NM='redis-key'
REDIS_INST_PROFILE_NM='MaxminRedisInstanceProfile'

## **************** ##
## AWS Sinatra box  ##
## **************** ##

SINATRA_INST_NM='sinatra-box'
SINATRA_INST_PRIVATE_IP='10.0.10.33'
SINATRA_HTTP_PORT='4567'
SINATRA_INST_HOSTNAME='sinatra.maxmin.it'
SINATRA_INST_SEC_GRP_NM='sinatra-sgp'
SINATRA_INST_KEY_PAIR_NM='sinatra-key'
SINATRA_INST_PROFILE_NM='MaxminSinatraInstanceProfile'
SINATRA_INST_DIR='/opt/sinatra'


