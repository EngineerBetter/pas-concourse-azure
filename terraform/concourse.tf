variable "subscription_id" {}

variable "tenant_id" {}

variable "client_id" {}

variable "client_secret" {}

variable "env_id" {}

variable "region" {}

variable "network_cidr" {
  default = "10.0.0.0/16"
}

variable "simple_env_id" {}

variable "internal_cidr" {
  default = "10.0.0.0/16"
}

terraform {
  backend "azurerm" {
    key = "concourse.tfstate"
  }
}

provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  tenant_id       = "${var.tenant_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"

  version = "~> 1.22"
}

provider "tls" {
  version = "~> 1.2"
}

provider "random" {
  version = "~> 2.0"
}

resource "azurerm_resource_group" "concourse" {
  name     = "${var.env_id}-concourse"
  location = "${var.region}"

  tags {
    environment = "${var.env_id}"
  }
}

resource "azurerm_public_ip" "bosh" {
  name                         = "${var.env_id}-bosh"
  location                     = "${var.region}"
  resource_group_name          = "${azurerm_resource_group.concourse.name}"
  public_ip_address_allocation = "static"

  tags {
    environment = "${var.env_id}"
  }
}

resource "azurerm_virtual_network" "bosh" {
  name                = "${var.env_id}-bosh-vn"
  address_space       = ["${var.network_cidr}"]
  location            = "${var.region}"
  resource_group_name = "${azurerm_resource_group.concourse.name}"
}

resource "azurerm_subnet" "bosh" {
  name                 = "${var.env_id}-bosh-sn"
  address_prefix       = "${cidrsubnet(var.network_cidr, 8, 0)}"
  resource_group_name  = "${azurerm_resource_group.concourse.name}"
  virtual_network_name = "${azurerm_virtual_network.bosh.name}"
}

resource "random_string" "account" {
  length  = 4
  upper   = false
  special = false
}

resource "azurerm_storage_account" "bosh" {
  name                = "${var.simple_env_id}${random_string.account.result}"
  resource_group_name = "${azurerm_resource_group.concourse.name}"

  location                 = "${var.region}"
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags {
    environment = "${var.env_id}"
  }

  lifecycle {
    ignore_changes = ["name"]
  }
}

resource "azurerm_storage_container" "bosh" {
  name                  = "bosh"
  resource_group_name   = "${azurerm_resource_group.concourse.name}"
  storage_account_name  = "${azurerm_storage_account.bosh.name}"
  container_access_type = "private"
}

resource "azurerm_storage_container" "stemcell" {
  name                  = "stemcell"
  resource_group_name   = "${azurerm_resource_group.concourse.name}"
  storage_account_name  = "${azurerm_storage_account.bosh.name}"
  container_access_type = "blob"
}

resource "azurerm_network_security_group" "bosh" {
  name                = "${var.env_id}-bosh"
  location            = "${var.region}"
  resource_group_name = "${azurerm_resource_group.concourse.name}"

  tags {
    environment = "${var.env_id}"
  }
}

resource "azurerm_network_security_rule" "ssh" {
  name                        = "${var.env_id}-ssh"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.concourse.name}"
  network_security_group_name = "${azurerm_network_security_group.bosh.name}"
}

resource "azurerm_network_security_rule" "bosh-agent" {
  name                        = "${var.env_id}-bosh-agent"
  priority                    = 201
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "6868"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.concourse.name}"
  network_security_group_name = "${azurerm_network_security_group.bosh.name}"
}

resource "azurerm_network_security_rule" "bosh-director" {
  name                        = "${var.env_id}-bosh-director"
  priority                    = 202
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "25555"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.concourse.name}"
  network_security_group_name = "${azurerm_network_security_group.bosh.name}"
}

resource "azurerm_network_security_rule" "dns" {
  name                        = "${var.env_id}-dns"
  priority                    = 203
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.concourse.name}"
  network_security_group_name = "${azurerm_network_security_group.bosh.name}"
}

resource "azurerm_network_security_rule" "credhub" {
  name                        = "${var.env_id}-credhub"
  priority                    = 204
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8844"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.concourse.name}"
  network_security_group_name = "${azurerm_network_security_group.bosh.name}"
}

output "vnet_name" {
  value = "${azurerm_virtual_network.bosh.name}"
}

output "subnet_name" {
  value = "${azurerm_subnet.bosh.name}"
}

output "resource_group_name" {
  value = "${azurerm_resource_group.concourse.name}"
}

output "storage_account_name" {
  value = "${azurerm_storage_account.bosh.name}"
}

output "default_security_group" {
  value = "${azurerm_network_security_group.bosh.name}"
}

output "external_ip" {
  value = "${azurerm_public_ip.bosh.ip_address}"
}

output "director_address" {
  value = "https://${azurerm_public_ip.bosh.ip_address}:25555"
}

output "private_key" {
  value     = "${tls_private_key.bosh_vms.private_key_pem}"
  sensitive = true
}

output "public_key" {
  value     = "${tls_private_key.bosh_vms.public_key_openssh}"
  sensitive = false
}

output "network_cidr" {
  value = "${var.network_cidr}"
}

output "director_name" {
  value = "bosh-${var.env_id}"
}

output "internal_cidr" {
  value = "${var.internal_cidr}"
}

output "subnet_cidr" {
  value = "${cidrsubnet(var.network_cidr, 8, 0)}"
}

output "internal_gw" {
  value = "${cidrhost(var.internal_cidr, 1)}"
}

resource "tls_private_key" "bosh_vms" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_public_ip" "concourse" {
  name                         = "${var.env_id}-concourse-lb"
  location                     = "${var.region}"
  resource_group_name          = "${azurerm_resource_group.concourse.name}"
  public_ip_address_allocation = "static"
  sku                          = "Standard"

  tags {
    environment = "${var.env_id}"
  }
}

resource "azurerm_lb" "concourse" {
  name                = "${var.env_id}-concourse-lb"
  resource_group_name = "${azurerm_resource_group.concourse.name}"
  location            = "${var.region}"
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "${var.env_id}-concourse-frontend-ip-configuration"
    public_ip_address_id = "${azurerm_public_ip.concourse.id}"
  }
}

resource "azurerm_lb_rule" "concourse-https" {
  name                = "${var.env_id}-concourse-https"
  resource_group_name = "${azurerm_resource_group.concourse.name}"
  loadbalancer_id     = "${azurerm_lb.concourse.id}"

  frontend_ip_configuration_name = "${var.env_id}-concourse-frontend-ip-configuration"
  protocol                       = "TCP"
  frontend_port                  = 443
  backend_port                   = 443

  backend_address_pool_id = "${azurerm_lb_backend_address_pool.concourse.id}"
  probe_id                = "${azurerm_lb_probe.concourse-https.id}"
}

resource "azurerm_lb_probe" "concourse-https" {
  name                = "${var.env_id}-concourse-https"
  resource_group_name = "${azurerm_resource_group.concourse.name}"
  loadbalancer_id     = "${azurerm_lb.concourse.id}"
  protocol            = "TCP"
  port                = 443
}

resource "azurerm_lb_rule" "concourse-http" {
  name                = "${var.env_id}-concourse-http"
  resource_group_name = "${azurerm_resource_group.concourse.name}"
  loadbalancer_id     = "${azurerm_lb.concourse.id}"

  frontend_ip_configuration_name = "${var.env_id}-concourse-frontend-ip-configuration"
  protocol                       = "TCP"
  frontend_port                  = 80
  backend_port                   = 80

  backend_address_pool_id = "${azurerm_lb_backend_address_pool.concourse.id}"
  probe_id                = "${azurerm_lb_probe.concourse-http.id}"
}

resource "azurerm_lb_probe" "concourse-http" {
  name                = "${var.env_id}-concourse-http"
  resource_group_name = "${azurerm_resource_group.concourse.name}"
  loadbalancer_id     = "${azurerm_lb.concourse.id}"
  protocol            = "TCP"
  port                = 80
}

resource "azurerm_lb_rule" "concourse-uaa" {
  name                = "${var.env_id}-concourse-uaa"
  resource_group_name = "${azurerm_resource_group.concourse.name}"
  loadbalancer_id     = "${azurerm_lb.concourse.id}"

  frontend_ip_configuration_name = "${var.env_id}-concourse-frontend-ip-configuration"
  protocol                       = "TCP"
  frontend_port                  = 8443
  backend_port                   = 8443

  backend_address_pool_id = "${azurerm_lb_backend_address_pool.concourse.id}"
  probe_id                = "${azurerm_lb_probe.concourse-uaa.id}"
}

resource "azurerm_lb_probe" "concourse-uaa" {
  name                = "${var.env_id}-concourse-uaa"
  resource_group_name = "${azurerm_resource_group.concourse.name}"
  loadbalancer_id     = "${azurerm_lb.concourse.id}"
  protocol            = "TCP"
  port                = 8443
}

resource "azurerm_lb_rule" "concourse-credhub" {
  name                = "${var.env_id}-concourse-credhub"
  resource_group_name = "${azurerm_resource_group.concourse.name}"
  loadbalancer_id     = "${azurerm_lb.concourse.id}"

  frontend_ip_configuration_name = "${var.env_id}-concourse-frontend-ip-configuration"
  protocol                       = "TCP"
  frontend_port                  = 8844
  backend_port                   = 8844

  backend_address_pool_id = "${azurerm_lb_backend_address_pool.concourse.id}"
  probe_id                = "${azurerm_lb_probe.concourse-credhub.id}"
}

resource "azurerm_lb_probe" "concourse-credhub" {
  name                = "${var.env_id}-concourse-credhub"
  resource_group_name = "${azurerm_resource_group.concourse.name}"
  loadbalancer_id     = "${azurerm_lb.concourse.id}"
  protocol            = "TCP"
  port                = 8844
}

resource "azurerm_network_security_rule" "concourse-http" {
  name                        = "${var.env_id}-concourse-http"
  priority                    = 209
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.concourse.name}"
  network_security_group_name = "${azurerm_network_security_group.bosh.name}"
}

resource "azurerm_network_security_rule" "concourse-https" {
  name                        = "${var.env_id}-concourse-https"
  priority                    = 208
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.concourse.name}"
  network_security_group_name = "${azurerm_network_security_group.bosh.name}"
}

resource "azurerm_network_security_rule" "concourse-credhub" {
  name                        = "${var.env_id}-uaa"
  priority                    = 207
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8844"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.concourse.name}"
  network_security_group_name = "${azurerm_network_security_group.bosh.name}"
}

resource "azurerm_network_security_rule" "uaa" {
  name                        = "${var.env_id}-uaa"
  priority                    = 206
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.concourse.name}"
  network_security_group_name = "${azurerm_network_security_group.bosh.name}"
}

resource "azurerm_lb_backend_address_pool" "concourse" {
  name                = "${var.env_id}-concourse-backend-pool"
  resource_group_name = "${azurerm_resource_group.concourse.name}"
  loadbalancer_id     = "${azurerm_lb.concourse.id}"
}

output "concourse_lb_name" {
  value = "${azurerm_lb.concourse.name}"
}

output "concourse_lb_ip" {
  value = "${azurerm_public_ip.concourse.ip_address}"
}

output "subscription_id" {
  value = "${var.subscription_id}"
}

output "tenant_id" {
  value = "${var.tenant_id}"
}

output "client_id" {
  value = "${var.client_id}"
}

output "client_secret" {
  value = "${var.client_secret}"
}
