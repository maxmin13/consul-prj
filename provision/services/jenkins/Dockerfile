##########################################################################################################
# jenkins/jenkins:lts image is the official Jenkins image maintained by their community on the Docker Hub.
# We installed the Docker binary. We use this to connect to our Docker host and run containers for our i
# mage to run Jenkins correctly.
# The 'jenkins' user is the default for the jenkins image and is required for containers launched from the 
# builds. 
##########################################################################################################

FROM jenkins/jenkins:lts
MAINTAINER maxmin@example.com
ENV REFRESHED_AT 2016-06-01

USER root
RUN apt-get -qqy update; apt-get install -qqy sudo wget
RUN echo "jenkins ALL=NOPASSWD: ALL" >> /etc/sudoers

RUN curl -L http://get.docker.com/builds/Linux/x86_64/docker-latest.tgz -o docker.tgz
RUN tar -xvzf docker.tgz
RUN mv docker/* /usr/bin/

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt 

USER jenkins



