# Builds an updated centos 8 image.
#
# Build:
#
#    docker build --rm -t="maxmin13/centos8:v1" .
#

FROM SEDrepository_uriSED:SEDimg_tagSED
LABEL version="1" maintainer="maxmin@example.com" description="Base centos 8 image"
ENV REFRESHED_AT SEDrefreshed_atSED

WORKDIR /etc/yum.repos.d/
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
RUN sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

RUN yum update -y
