# Builds an updated ruby image.
#
# Build:
#
#    docker build --rm -t="maxmin13/ruby:v1" .
#

FROM SEDruby_docker_repository_uriSED:SEDruby_docker_img_tagSED
LABEL maintainer="maxmin@example.com"
ENV REFRESHED_AT 2022-05-15

RUN yum update -y; yum install -y ruby rubygems ruby-devel
