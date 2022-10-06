# Jekyll is a tool that transforms plain text files into websites.
#
#   docker build -t="maxmin13/jekyll:v1" .
#
FROM SEDrepository_uriSED:SEDimg_tagSED
LABEL version="1" maintainer="maxmin@example.com" description="base centos 8 image"
ENV REFRESHED_AT SEDrefreshed_atSED

RUN yum update -y && gem install jekyll bundler
RUN bundle add webrick

VOLUME /data 
VOLUME /var/www/html 

WORKDIR /data 

ENTRYPOINT [ "bundle", "exec", "--destination =/var/www/html" ]


