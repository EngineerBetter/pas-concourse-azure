#!/usr/bin/env bash

set -euo pipefail

pushd terraform
terraform init \
  -backend-config="storage_account_name=${BACKEND_STORAGE_ACCOUNT_NAME}" \
  -backend-config="container_name=${BACKEND_CONTAINER_NAME}" \
  -backend-config="access_key=${BACKEND_ACCESS_KEY}"

terraform destroy \
  -var-file=concourse.tfvars \
  -auto-approve
popd
