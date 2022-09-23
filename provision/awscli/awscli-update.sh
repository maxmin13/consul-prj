#!/bin/bash

########################################################################
#
# Removes the installed awscli and installs awscli version 2.
#
########################################################################

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

remote_dir='SEDscripts_dirSED'

echo 'Removing the installed version of awscli ...'

# remove version 1
yum remove -y awscli

# remove version 2 
rm -rf /usr/local/aws-cli/

echo 'awscli removed.'
echo 'Installing awscli version 2 ...'

cd "${remote_dir}"
mkdir -p awscli 

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscli/awscliv2.zip
unzip -d awscli awscli/awscliv2.zip
sudo ./awscli/aws/install

rm -rf awscli

echo 'awscli installed.'

/usr/local/bin/aws --version

echo
