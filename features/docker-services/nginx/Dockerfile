######################################################################################################
# Runs an nginx server on port 80 and deploys a static website from a volume mounted from the host.
#
# Build:
#
#    docker build -t="maxmin13/nginx:v1" .
#
# Run the server in the docker0 subnet:
#
#    docker run -d -p 80:80 --name website 
#        --build-arg NGINX_HTTP_PORT=80 
#        -v $PWD/website:/var/www/html/website:ro maxmin13/nginx:v1 
# 
# Access the website:
#
#    http://localhost
######################################################################################################

FROM SEDrepository_uriSED:SEDimg_tagSED
LABEL version="1" maintainer="maxmin@example.com" description="Nginx image"
ENV REFRESHED_AT SEDrefreshed_atSED

RUN yum update -y && yum install -y nginx;
RUN mkdir -p SEDcontainer_volume_dirSED
RUN useradd -M -s /sbin/nologin www 

ADD global.conf /etc/nginx/conf.d
ADD nginx.conf /etc/nginx

EXPOSE SEDhttp_portSED
ENTRYPOINT nginx

