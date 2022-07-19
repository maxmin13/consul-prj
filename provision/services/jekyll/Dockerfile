# Jekyll is a tool that transforms plain text files into websites.
#
#   docker build -t="maxmin13/jekyll:v1" .
#
FROM maxmin13/ruby:v1
LABEL maintainer="maxmin@example.com"
ENV REFRESHED_AT 2022-05-15

RUN yum update -y && gem install jekyll bundler
RUN bundle add webrick

VOLUME /data 
VOLUME /var/www/html 

WORKDIR /data 

ENTRYPOINT [ "bundle", "exec", "--destination =/var/www/html" ]


