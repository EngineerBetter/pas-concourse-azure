#!/usr/bin/env bash

set -ueo pipefail

: "${BACKEND_STORAGE_ACCOUNT_NAME:?BACKEND_STORAGE_ACCOUNT_NAME the storage account name to be used for the terraform backend}"
: "${BACKEND_CONTAINER_NAME:?BACKEND_CONTAINER_NAME the container name to be used for the terraform backend}"
: "${BACKEND_ACCESS_KEY:?BACKEND_ACCESS_KEY the key to be used for the terraform backend}"
: "${CONCOURSE_PASSWORD:?CONCOURSE_PASSWORD the password for the Concourse admin user}"

echo "================================"
echo "Terraforming infra"
echo "================================"

pushd terraform
terraform init \
  -backend-config="storage_account_name=${BACKEND_STORAGE_ACCOUNT_NAME}" \
  -backend-config="container_name=${BACKEND_CONTAINER_NAME}" \
  -backend-config="access_key=${BACKEND_ACCESS_KEY}"

terraform apply \
  -var-file=concourse.tfvars \
  -auto-approve

client_id="$(terraform output client_id)"
client_secret="$(terraform output client_secret)"
concourse_lb_ip="$(terraform output concourse_lb_ip)"
concourse_lb_name="$(terraform output concourse_lb_name)"
default_security_group="$(terraform output default_security_group)"
director_internal_ip="$(terraform output director_internal_ip)"
external_ip="$(terraform output external_ip)"
internal_cidr="$(terraform output internal_cidr)"
internal_gw="$(terraform output internal_gw)"
resource_group_name="$(terraform output resource_group_name)"
storage_account_name="$(terraform output storage_account_name)"
subnet_cidr="$(terraform output subnet_cidr)"
subnet_name="$(terraform output subnet_name)"
subscription_id="$(terraform output subscription_id)"
tenant_id="$(terraform output tenant_id)"
vnet_name="$(terraform output vnet_name)"
popd

mkdir -p bosh-files

echo "================================"
echo "Deploying BOSH director"
echo "================================"
bosh create-env bosh-deployment/bosh.yml \
  --state=bosh-files/state.json \
  --vars-store=bosh-files/creds.yml \
  -o bosh-deployment/azure/cpi.yml \
  -o bosh-deployment/uaa.yml \
  -o bosh-deployment/external-ip-with-registry-not-recommended.yml \
  -o bosh-deployment/external-ip-not-recommended-uaa.yml \
  -o bosh-deployment/credhub.yml \
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

BOSH_CLIENT="admin"
BOSH_CLIENT_SECRET=$(bosh int bosh-files/creds.yml --path /admin_password)
bosh int bosh-files/creds.yml --path /director_ssl/ca > bosh-files/bosh_ca.pem
BOSH_CA_CERT="$PWD/bosh-files/bosh_ca.pem"
BOSH_ENVIRONMENT="${external_ip}"

export BOSH_CLIENT BOSH_CLIENT_SECRET BOSH_CA_CERT BOSH_ENVIRONMENT

bosh env

echo "================================"
echo "Uploading stemcell"
echo "================================"
bosh upload-stemcell https://bosh.io/d/stemcells/bosh-azure-hyperv-ubuntu-xenial-go_agent

echo "================================"
echo "Updating cloud-config"
echo "================================"
pushd cloud-config
  bosh update-cloud-config cloud-config.yml \
    -o ops.yml \
    --var internal_gw="${internal_gw}" \
    --var subnet_cidr="${subnet_cidr}" \
    --var director_internal_ip="${director_internal_ip}" \
    --var vnet_name="${vnet_name}" \
    --var subnet_name="${subnet_name}" \
    --var default_security_group="${default_security_group}" \
    --var concourse_lb_name="${concourse_lb_name}" \
    --non-interactive
popd

echo "================================"
echo "Deploying Concourse"
echo "================================"
pushd manifests
  bosh deploy -d concourse concourse.yml \
    --vars-store ../bosh-files/concourse-creds.yml \
    --var atc_password="${CONCOURSE_PASSWORD}" \
    --var external_host="${concourse_lb_ip}" \
    --non-interactive
popd
