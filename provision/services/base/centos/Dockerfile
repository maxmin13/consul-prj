# Builds an updated centos 8 image.
#
# Build:
#
#    docker build --rm -t="maxmin13/centos8:v1" .
#
FROM SEDbase_centos_docker_repository_uriSED:SEDbase_centos_docker_img_tagSED
LABEL version="1" maintainer="maxmin@example.com" description="base centos 8 image"
ENV REFRESHED_AT 2014-06-01

WORKDIR /etc/yum.repos.d/
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
RUN sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

RUN yum update -y
