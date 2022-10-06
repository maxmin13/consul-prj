# Sinatra is a DSL (Domain Specific Language) intended for quickly creating web-applications in Ruby with minimal effort.
#
#   docker network create appnet
#   docker build -t="maxmin13/sinatra:v1" .
#   docker run -d --net appnet --name webapp -v $PWD/webapp:/opt/webapp maxmin13/sinatra:v1
#
#####################

FROM SEDrepository_uriSED:SEDimg_tagSED
LABEL version="1" maintainer="maxmin@example.com" description="Sinatra image."
ENV REFRESHED_AT SEDrefreshed_atSED

RUN yum update -y && ruby -v && gem install sinatra redis
RUN mkdir -p SEDcontainer_volume_dirSED

EXPOSE SEDhttp_portSED



