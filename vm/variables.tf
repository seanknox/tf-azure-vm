variable "name" {}
variable "vm_size" {}

variable "admin_username" {
  default = "azureuser"
}

variable "cloud_config" {
  type = "string"
}

variable "location" {
  type = "string"
}

variable "resource_group_name" {
  type = "string"
}

variable "availability_set_id" {
  type = "string"
}

variable "subnet_id" {
  type = "string"
}

variable "storage_type" {}

variable "tags" {
  type = "map"
}

variable "ssh_key" {}

variable "ssh_port" {
  default = "22"
}
