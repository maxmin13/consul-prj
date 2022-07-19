
Installs on AWS:

 Jenkins from the official jenkins/jenkins:lts Docker image.
 an Nginx server built from a centos Docker image, for static websites.
 a Redis database build from the a centos Docker image.


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
