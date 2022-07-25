#!/usr/bin/bash

# shellcheck disable=SC2034

## ******************* ##
## Base Docker images  ##
## ******************* ##

CENTOS_DOCKER_IMG_NM='maxmin13/centos8'
CENTOS_DOCKER_IMG_TAG='v1'
RUBY_DOCKER_IMG_NM='maxmin13/ruby'
RUBY_DOCKER_IMG_TAG='v1'

## ******************* ##
##      Jenkins        ##
## ******************* ##

JENKINS_DOCKER_CONTAINER_NM='jenkins'
JENKINS_DOCKER_IMG_NM='maxmin13/jenkins'
JENKINS_DOCKER_IMG_TAG='v1'

## ******************* ##
##        Nginx        ##
## ******************* ##

NGINX_DOCKER_CONTAINER_NM='nginx'
NGINX_DOCKER_IMG_NM='maxmin13/nginx'
NGINX_DOCKER_IMG_TAG='v1'
NGINX_CONTAINER_VOLUME_DIR='/var/www/html'

## ******************* ##
##   Redis database    ##
## ******************* ##

REDIS_DOCKER_IMG_NM='maxmin13/redis'
REDIS_DOCKER_IMG_TAG='v1'
REDIS_DOCKER_CONTAINER_NM='redis'
REDIS_DOCKER_CONTAINER_NETWORK_NM='sinatra-redis-net'
REDIS_DOCKER_CONTAINER_NETWORK_CIDR='192.168.1.0/24'
REDIS_DOCKER_CONTAINER_NETWORK_GATE='192.168.1.1'

## ******************* ##
##   Sinatra webapp    ##
## ******************* ##

SINATRA_DOCKER_IMG_NM='maxmin13/sinatra'
SINATRA_DOCKER_IMG_TAG='v1'
SINATRA_DOCKER_CONTAINER_NM='sinatra'
SINATRA_DOCKER_CONTAINER_NETWORK_NM='sinatra-redi-net'
SINATRA_DOCKER_CONTAINER_NETWORK_CIDR='192.168.1.0/24'
SINATRA_DOCKER_CONTAINER_NETWORK_GATE='192.168.1.1'
SINATRA_CONTAINER_VOLUME_DIR='/opt/sinatra'

