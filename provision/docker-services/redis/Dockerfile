#####################################################################################################################
# Redis database accessible on port 6379:
#
#   docker build -t="maxmin13/redis:v1" .
#   docker run -d --net appnet --name redisdb maxmin13/redis:v1
#   docker exec -ti redisdb /bin/bash
#   redis-cli -h 127.0.0.1 -p 6379 # test the connection by adding: -p 6379:6379 
#
#   docker inspect redisdb  | jq '.[].NetworkSettings'
#   docker inspect -f '{{ .NetworkSettings.IPAddress }}' redisdb
#   docker inspect -f '{{ .NetworkSettings.Gateway }}' redisdb
#   docker inspect --format='{{(index (index .NetworkSettings.Ports "6379/tcp") 0).HostPort}}' redisdb
#   docker port redisdb
#
#####################################################################################################################

FROM SEDrepository_uriSED:SEDimg_tagSED
LABEL version="1" maintainer="maxmin@example.com" description="Redis database image"
ENV REFRESHED_AT SEDrefreshed_atSED
 
RUN yum update -y && yum install -y redis

ADD redis.conf /usr/local/etc/redis/

EXPOSE SEDhttp_portSED

ENTRYPOINT ["redis-server", "/usr/local/etc/redis/redis.conf" ] 
CMD []
