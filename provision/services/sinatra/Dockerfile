# Sinatra is a DSL (Domain Specific Language) intended for quickly creating web-applications in Ruby with minimal effort.
#
#   docker network create appnet
#   docker build -t="maxmin13/sinatra:v1" .
#   docker run -d --net appnet --name webapp -v $PWD/webapp:/opt/webapp maxmin13/sinatra:v1
#

#####################

FROM SEDrepository_uriSED:SEDimg_tagSED
LABEL maintainer="maxmin@example.com"
ENV REFRESHED_AT 2022-05-15
ARG SINATRA_HTTP_PORT

RUN yum update -y && gem install sinatra redis 
RUN mkdir -p SEDcontainer_volume_dirSED

EXPOSE $SINATRA_HTTP_PORT

CMD SEDcontainer_volume_dirSED/webapp/bin/run


