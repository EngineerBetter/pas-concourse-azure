#!/usr/bin/env bash

set -ueo pipefail

: "${BACKEND_STORAGE_ACCOUNT_NAME:?BACKEND_STORAGE_ACCOUNT_NAME the storage account name to be used for the terraform backend}"
: "${BACKEND_CONTAINER_NAME:?BACKEND_CONTAINER_NAME the container name to be used for the terraform backend}"
: "${BACKEND_ACCESS_KEY:?BACKEND_ACCESS_KEY the key to be used for the terraform backend}"

pushd terraform
terraform init \
  -backend-config="storage_account_name=${BACKEND_STORAGE_ACCOUNT_NAME}" \
  -backend-config="container_name=${BACKEND_CONTAINER_NAME}" \
  -backend-config="access_key=${BACKEND_ACCESS_KEY}"

terraform apply \
  -var-file=concourse.tfvars \
  -auto-approve
popd
