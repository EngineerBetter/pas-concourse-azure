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

internal_gw="$(terraform output internal_gw)"
internal_cidr="$(terraform output internal_cidr)"
director_internal_ip="$(terraform output director_internal_ip)"
external_ip="$(terraform output external_ip)"
vnet_name="$(terraform output vnet_name)"
subnet_name="$(terraform output subnet_name)"
resource_group_name="$(terraform output resource_group_name)"
storage_account_name="$(terraform output storage_account_name)"
default_security_group="$(terraform output default_security_group)"
subscription_id="$(terraform output subscription_id)"
tenant_id="$(terraform output tenant_id)"
client_id="$(terraform output client_id)"
client_secret="$(terraform output client_secret)"
popd

mkdir -p bosh-files

bosh create-env bosh-deployment/bosh.yml \
  --state=bosh-files/state.json \
  --vars-store=bosh-files/creds.yml \
  -o bosh-deployment/azure/cpi.yml \
  -o bosh-deployment/external-ip-with-registry-not-recommended.yml \
  -v external_ip="${external_ip}" \
  -v director_name=concourse-director \
  -v internal_cidr="${internal_cidr}" \
  -v internal_gw="${internal_gw}" \
  -v internal_ip="${director_internal_ip}" \
  -v vnet_name="${vnet_name}" \
  -v subnet_name="${subnet_name}" \
  -v subscription_id="${subscription_id}" \
  -v tenant_id="${tenant_id}" \
  -v client_id="${client_id}" \
  -v client_secret="${client_secret}" \
  -v resource_group_name="${resource_group_name}" \
  -v storage_account_name="${storage_account_name}" \
  -v default_security_group="${default_security_group}"
