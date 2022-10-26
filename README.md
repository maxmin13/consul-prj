
## AWS datacenter

Amazon AWS datacenter that runs AWS EC2 instances with Linux 2 os. Every instance runs a Docker service:
Nginx server, Sinatra server, Redis database, Jenkins pipeline.

![alt text](https://github.com/maxmin13/consul-prj/blob/master/img/vpc.png)

The Admin instance acts as a jumpbox. Dockerfiles are uploaded to it and the images for each service are built
and uploaded to AWS ECR registry. Each instance downloads the image from the registry and runs a container from it.

![alt text](https://github.com/maxmin13/consul-prj/blob/master/img/ecr.png)

A cluster of Consul agensts is run in the datacenter. The admin instance runs a Consul server agent, each other instance a 
Consul client agent. The gossip in the cluster is exchanged thourgh 10.0.10.0/24 subnet.


![alt text](https://github.com/maxmin13/consul-prj/blob/master/img/consul-admin.png)

```

aws-cli/2.7.34

cd aws-datacenter
amazon/run/make.sh

```

## Delete the datacenter

```
cd aws-datacenter
amazon/run/delete.sh

```

