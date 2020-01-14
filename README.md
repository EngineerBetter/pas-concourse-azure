# PAS Concourse Azure

Some scripts for bootstrapping a BOSH director and an OSS Concourse on MS Azure.

Not fully automated and more of a PoC/starting point than a production deployment.

## Prerequisites

You will need:

- a service principal
- a storage account with a container called `terraform`

## Variables

Copy `terraform/concourse.tfvars.template` to `terraform/concourse.tfvars` and fill it in.

## Deploy

```sh
BACKEND_STORAGE_ACCOUNT_NAME=<name of your pre-existing storage account> \
  BACKEND_CONTAINER_NAME="terraform" \
  BACKEND_ACCESS_KEY=<access key of your pre-existing storage account> \
  ./deploy.sh
```

*NOTE*: ensure you store the files in `bosh-files` somewhere safe as they are the state of your deployment. They contain secrets so don't push them to git.

## Connect to director

```sh
# Configure local alias
bosh int bosh-files/creds.yml --path /director_ssl/ca > bosh-files/bosh_ca.pem
bosh int bosh-files/creds.yml --path /ssh/private_key > bosh-files/bosh_gw_key.pem
chmod 600 bosh-files/*.pem
BOSH_GW_USER=vcap
BOSH_GW_PRIVATE_KEY="${PWD}/bosh-files/bosh_gw_key.pem"
BOSH_CA_CERT="$PWD/bosh-files/bosh_ca.pem"
BOSH_CLIENT=admin
BOSH_CLIENT_SECRET=$(bosh int bosh-files/creds.yml --path /admin_password)
BOSH_ENVIRONMENT=<external ip of your director>
export BOSH_GW_USER BOSH_GW_PRIVATE_KEY BOSH_CA_CERT BOSH_CLIENT BOSH_CLIENT_SECRET BOSH_ENVIRONMENT
```

## Destroy

```sh
BACKEND_STORAGE_ACCOUNT_NAME=<name of your pre-existing storage account> \
  BACKEND_CONTAINER_NAME="terraform" \
  BACKEND_ACCESS_KEY=<access key of your pre-existing storage account> \
  ./destroy.sh
```
