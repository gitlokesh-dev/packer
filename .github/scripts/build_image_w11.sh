#!/bin/bash
# Example build script
if [ "$#" -lt 7 ]; then
  echo "Usage: $0 <subscription_id> <client_id> <client_secret> <tenant_id> <resource_group> <location> <image_name>"
  exit 1
fi
SUBSCRIPTION_ID=$1
CLIENT_ID=$2
CLIENT_SECRET=$3
TENANT_ID=$4
RG=$5
LOCATION=$6
IMAGE_NAME=$7

export PACKER_VAR_subscription_id=${SUBSCRIPTION_ID}
export PACKER_VAR_client_id=${CLIENT_ID}
export PACKER_VAR_client_secret=${CLIENT_SECRET}
export PACKER_VAR_tenant_id=${TENANT_ID}
export PACKER_VAR_resource_group=${RG}
export PACKER_VAR_location=${LOCATION}
export PACKER_VAR_w11_image_name=${IMAGE_NAME}

cd packer
packer init .
packer build windows11.pkr.hcl
