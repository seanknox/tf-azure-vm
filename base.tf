provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  version         = "~> 1.12"
}

locals {

  tags = {
    environment = "dev"
  }

  shared_prefix         = "${var.location}-${var.alias}-dev"
  vnet_address_space    = "10.0.0.0/16"
  vnet_name             = "default"
  subnet_name           = "default"
  subnet_address_prefix = "10.0.0.0/24"
}

# Resource group
resource "azurerm_resource_group" "rg" {
  name     = "${local.shared_prefix}"
  location = "${var.location}"
  tags     = "${merge(local.tags, map("provisionedBy", "terraform"))}"
}

# Networking
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.vnet_name}"
  location            = "${azurerm_resource_group.rg.location}"
  address_space       = ["${local.vnet_address_space}"]
  resource_group_name = "${azurerm_resource_group.rg.name}"
  tags                = "${local.tags}"
}

resource "azurerm_subnet" "default" {
  name                 = "${local.subnet_name}"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  address_prefix       = "${local.subnet_address_prefix}"
}

resource "azurerm_availability_set" "machines" {
  name                = "${local.shared_prefix}"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  # NOTE: The number of Fault Domains varies depending on which Azure Region you're using - a list can be found here: https://github.com/MicrosoftDocs/azure-docs/blob/master/includes/managed-disks-common-fault-domain-region-list.md
  # We default to 2
  platform_fault_domain_count = 2
  managed                     = true
  tags                        = "${local.tags}"
}

data "template_file" "cloud_config" {
  template = "${file("${path.module}/cloud-config/${var.cloud_config}")}"

  vars = {
    ssh_port       = "${var.ssh_port}"
    ssh_key        = "${var.ssh_key}"
    admin_username = "${var.admin_username}"
  }
}

module "vm" {
  source = "./vm"

  name                = "${local.shared_prefix}"
  vm_size             = "${var.standard_vm_size}"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  admin_username      = "${var.admin_username}"
  ssh_key             = "${var.ssh_key}"
  ssh_port            = "${var.ssh_port}"

  // this is something that annoys me - passing the resource would be nicer
  availability_set_id = "${azurerm_availability_set.machines.id}"
  subnet_id           = "${azurerm_subnet.default.id}"
  storage_type        = "${var.storage_type}"
  tags                = "${local.tags}"
  cloud_config        = "${base64encode(data.template_file.cloud_config.rendered)}"
}
