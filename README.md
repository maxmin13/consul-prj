


## AWS datacenter

Amazon AWS datacenter that runs EC2 instances with Linux 2 os. Every instance runs a Docker service:
Nginx server, Sinatra server, Redis database, Jenkins pipeline.

![alt text](https://github.com/maxmin13/consul-prj/blob/master/img/vpc.png)

The Admin instance acts as a jumpbox. Dockerfiles are uploaded to it and the images for each service are built
and uploaded to AWS Ecr registry. Each instance download the images from the registry and runs a container from it.

![alt text](https://github.com/maxmin13/consul-prj/blob/master/img/ecr.png)


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

