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

## ******************* ##
##   Sinatra webapp    ##
## ******************* ##

SINATRA_DOCKER_IMG_NM='maxmin13/sinatra'
SINATRA_DOCKER_IMG_TAG='v1'
SINATRA_DOCKER_CONTAINER_NM='sinatra'
SINATRA_DOCKER_CONTAINER_VOLUME_DIR='/opt/sinatra'
SINATRA_DOCKER_HOST_VOLUME_DIR='/opt/sinatra'

## ************************* ##
##   Sinatra/Redis network   ##
## ************************* ##

SINA_REDIS_NETWORK_NM='sinatra-redis-net'
SINA_REDIS_NETWORK_CIDR='192.168.1.0/24'
SINA_REDIS_NETWORK_GATE='192.168.1.1'




