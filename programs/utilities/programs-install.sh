#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

REMOTE_DIR='SEDremote_dirSED'
	
echo 'Installing utilities ...'

yum install -y jq

echo 'Utilities installed.'

echo
