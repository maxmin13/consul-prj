# Builds an updated ruby image.
#
# Build:
#
#    docker build --rm -t="maxmin13/ruby:v1" .
#

FROM SEDrepository_uriSED:SEDimg_tagSED
LABEL version="1" maintainer="maxmin@example.com" description="Base centos 8 image with Ruby"
ENV REFRESHED_AT SEDrefreshed_atSED

RUN dnf module reset ruby && dnf module -y install ruby:2.6 && ruby -v && dnf install -y rubygems ruby-devel

