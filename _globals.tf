variable "subscription_id" {
  description = "The Azure Subscription in which you're building this VM stack"
}

variable "location" {
  description = "The Azure Region in which you're building this VM stack (make sure you have quota!)"
}

variable "alias" {
  type = "string"
}

variable "ssh_key" {
  type = "string"
}

variable "admin_username" {
  type    = "string"
  default = "azureuser"
}

variable "ssh_port" {
  default = "22"
}

variable "standard_vm_size" {
  default = "Standard_B1s"
}

variable "storage_type" {
  default = "Premium_LRS"
}

variable "cloud_config" {
  default = "base.yml.tpl"
}

output "fqdn" {
  value = "${module.vm.fqdn}"
}
