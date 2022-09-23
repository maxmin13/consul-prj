
aws-cli/2.7.34

Installs on AWS:

 Jenkins from the official jenkins/jenkins:lts Docker image.
 Nginx server built from a centos Docker image, for static websites.
 Redis database build from the a centos Docker image.


## Create the AWS datacenter

```
cd aws-datacenter
amazon/run/make.sh

```

## Delete the datacenter

```
cd aws-datacenter
amazon/run/delete.sh

```
