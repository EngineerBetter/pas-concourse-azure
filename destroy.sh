#!/usr/bin/env bash

set -euo pipefail

read -p "Are you sure you want to delete everything? This can't be undone [y/N] " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
  exit 1
fi

pushd terraform
  terraform output > /dev/null 2>&1 || { echo "Already deleted" ; exit 0; }
  client_id="$(terraform output client_id)"
  client_secret="$(terraform output client_secret)"
  default_security_group="$(terraform output default_security_group)"
  director_internal_ip="$(terraform output director_internal_ip)"
  external_ip="$(terraform output external_ip)"
  internal_cidr="$(terraform output internal_cidr)"
  internal_gw="$(terraform output internal_gw)"
  resource_group_name="$(terraform output resource_group_name)"
  storage_account_name="$(terraform output storage_account_name)"
  subnet_name="$(terraform output subnet_name)"
  subscription_id="$(terraform output subscription_id)"
  tenant_id="$(terraform output tenant_id)"
  vnet_name="$(terraform output vnet_name)"
popd

BOSH_CLIENT="admin"
BOSH_CLIENT_SECRET=$(bosh int bosh-files/creds.yml --path /admin_password)
bosh int bosh-files/creds.yml --path /director_ssl/ca > bosh-files/bosh_ca.pem
BOSH_CA_CERT="$PWD/bosh-files/bosh_ca.pem"
BOSH_ENVIRONMENT="${external_ip}"

export BOSH_CLIENT BOSH_CLIENT_SECRET BOSH_CA_CERT BOSH_ENVIRONMENT

set +e
echo "================================"
echo "Deleting Concourse"
echo "================================"
bosh -d concourse delete-deployment --non-interactive

echo "================================"
echo "Cleaning up orphaned BOSH stuff"
echo "================================"
bosh clean-up --all --non-interactive

echo "================================"
echo "Deleting BOSH director"
echo "================================"
bosh delete-env bosh-deployment/bosh.yml \
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
  -v default_security_group="${default_security_group}" \
  --non-interactive

echo "================================"
echo "Deleting infra"
echo "================================"
pushd terraform
  terraform destroy \
    -var-file=concourse.tfvars \
    -auto-approve
popd


echo "================================"
echo "Destroy Complete"
# shellcheck disable=2016
echo 'delete `bosh-files` if you want to deploy a new Concourse with different creds next time'
echo "================================"
