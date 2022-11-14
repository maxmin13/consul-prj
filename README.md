
# Consul datacenter
 
Amazon AWS datacenter that runs AWS EC2 instances with Linux 2 os. Every instance runs a Docker service:
Nginx server, Sinatra server, Redis database, Jenkins pipeline.
<br/><br/> 

![alt text](https://github.com/maxmin13/consul-prj/blob/master/img/vpc.png)

<br/> 
The Admin instance acts as a jumpbox. Dockerfiles are uploaded to it and the images for each service are built
and uploaded to AWS ECR registry. Each instance downloads the image from the registry and runs a container from it.
<br/><br/>  

![alt text](https://github.com/maxmin13/consul-prj/blob/master/img/ecr.png)

<br/> 
A cluster of Consul agensts is run in the datacenter.
<br/> 
The admin instance acts as Consul server agent, each other instance as Consul client agent.
<br/> 
Consul web ui is published at the address:
***<pre>  http://${admin-instance-public-ip}/ui/consul</pre>*** 
In each instance Consul is configured to bind its HTTP, CLI RPC, and DNS services to the 169.254.1.1 address.
<br/> 
The cluster gossip is exchanged in the 10.0.10.0/24 network.
<br/>
dnsmaq acts as DNS service for the instance and the containers. It passes queries ending in .consul to the Consul agent, while
all the remaining queries are passed to the AWS DNS service at 10.0.0.2.
<br/>
A Registrator container in each instance automatically registers and deregisters with Consul services for any Docker container by inspecting containers as they come online.
<br/><br/>  

![alt text](https://github.com/maxmin13/consul-prj/blob/master/img/consul-admin.png)

<br/> 

In each AWS instance or in each container, Consul services can be queried by calling:
***<pre>  curl http://${CONSUL_HTTP_ADDR}/v1/catalog/service/jenkins?pretty</pre>*** 
where CONSUL_HTTP_ADDR is an environment variable.<br/><br/>
***<pre>  dig jenkins.maxmin.it.node.consul</pre>***
In an application running in a Ruby container, 
an example of the code to retrieve the database address and port may be:

```
uri = URI.parse("http://#{ENV['CONSUL_HTTP_ADDR']}/v1/catalog/service/redis?pretty")
http = Net::HTTP.new(uri.host, uri.port)

# Consul api call.
request = Net::HTTP::Get.new(uri.request_uri)
response = http.request(request)
body = response.body
address = JSON.parse(body)[0]['ServiceAddress']
port = JSON.parse(body)[0]['ServicePort']
redis = Redis.new(:host => address, :port => port)
```

<br/> 
# Deployment
## Required
<br/> 

```
Fedora
AWS account
aws-cli/2.7.34
jq-1.6
```

<br/> 
## Configure
<br/> 

```
Edit datacenter_consts.json, set Region and Az values.
```
<br/> 
## Istall
<br/> 

```
cd consul-prj
amazon/run/make.sh
```

<br/> 
## Delete
<br/> 

```
cd consul-prj
amazon/run/delete.sh
```

<br/> 
# Sinatra application
<br/> 
Ruby-based web application with a Redis back end. 
The incoming URL parameters are stored in the Redis database and they are returned as a Json file when requested.</br>
***<pre>  http://${sinatra-instance-public-ip}:4567/info</pre>***
***<pre>  curl -i -H 'Accept: application/json' -d 'name=Foo33&status=Bar33' http://${sinatra-instance-public-ip}:4567/json</pre>***
***<pre>  curl -i -H 'Accept: application/json' http://${sinatra-instance-public-ip}:4567/json</pre>***
The Sinatra web application and Redis database are run in Docker containers on different AWS instances/Docker engines.</br>
Their host instances partecipate in a Docker swarm with the Admin AWS instance. On top of the swarm has been laid a Docker overlay network, ***sinnet3***.
The two apps communicate in this network.
<br/> 

![alt text](https://github.com/maxmin13/consul-prj/blob/master/img/overlay.png)

</br>
# Nginx website
<br/> 
Standalone web application that displays a single static page, attached to the defaul Docker bridge network.
***<pre>  http://${nginx-instance-public-ip}:80/welcome</pre>***
<br/> 
# Jenkins pipeline
<br/> 
Standalone web application, attached to the defaul Docker bridge network.
***<pre>  http://${jenkins-instance-public-ip}:80/jenkins</pre>***
<br/> 


