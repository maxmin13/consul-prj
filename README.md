
## AWS datacenter

Amazon AWS datacenter that runs AWS EC2 instances with Linux 2 os. Every instance runs a Docker service:
Nginx server, Sinatra server, Redis database, Jenkins pipeline.

![alt text](https://github.com/maxmin13/consul-prj/blob/master/img/vpc.png)

The Admin instance acts as a jumpbox. Dockerfiles are uploaded to it and the images for each service are built
and uploaded to AWS ECR registry. Each instance downloads the image from the registry and runs a container from it.

![alt text](https://github.com/maxmin13/consul-prj/blob/master/img/ecr.png)

A cluster of Consul agensts is run in the datacenter.<br/> 
The admin instance runs a Consul server agent, each other instance a Consul client agent.<br/> 
Consul is configured to bind its HTTP, CLI RPC, and DNS interfaces to the 169.254.1.1 address..<br/> 
The cluster gossip is exchanged in the 10.0.10.0/24 subnet.<br/>
dnsmaq acts as DNS service for the instance and the containers. It passes queries ending in .consul to the Consul agent while
all the remaining queries are passed to the AWS DNS service at 10.0.0.2.<br/>
In each AWS instance or in each container, Consul HTTP service can be queried by calling:<br/>
<br/>
curl http://169.254.1.1:8500/v1/catalog/service/jenkins-service?pretty
<br/>
while Consul DNS service can be called with:<br/>
<br/>
dig jenkins.maxmin.it.node.consul
<br/>


![alt text](https://github.com/maxmin13/consul-prj/blob/master/img/consul-admin.png)

```

aws-cli/2.7.34
jq-1.6

cd aws-datacenter
amazon/run/make.sh

```

## Delete the datacenter

```
cd aws-datacenter
amazon/run/delete.sh

```

