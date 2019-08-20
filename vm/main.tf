resource "azurerm_network_security_group" "inbound" {
  name                = "${var.name}"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "${var.ssh_port}"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = "${var.tags}"
}

resource "azurerm_public_ip" "linux" {
  name                    = "${var.name}"
  location                = "${var.location}"
  resource_group_name     = "${var.resource_group_name}"
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30
  domain_name_label       = "${var.resource_group_name}"

  tags = "${var.tags}"
}

resource "azurerm_network_interface" "nic" {
  name                      = "${var.name}"
  location                  = "${var.location}"
  resource_group_name       = "${var.resource_group_name}"
  network_security_group_id = "${azurerm_network_security_group.inbound.id}"

  ip_configuration {
    name                          = "${var.name}-config"
    subnet_id                     = "${var.subnet_id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.linux.id}"
  }

  tags = "${var.tags}"
}

resource "azurerm_virtual_machine" "linux" {
  name                  = "${var.name}"
  location              = "${var.location}"
  resource_group_name   = "${var.resource_group_name}"
  availability_set_id   = "${var.availability_set_id}"
  network_interface_ids = ["${azurerm_network_interface.nic.id}"]
  vm_size               = "${var.vm_size}"

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${var.name}-os"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "${var.storage_type}"
  }

  os_profile {
    computer_name  = "${var.name}"
    admin_username = "${var.admin_username}"
    custom_data    = "${var.cloud_config}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      key_data = "${var.ssh_key}"
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
    }
  }

  tags = "${var.tags}"
}

output "virtual_machine" {
  value = "${azurerm_virtual_machine.linux.id}"
}
