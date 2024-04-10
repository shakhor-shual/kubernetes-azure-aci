variable "instances" {
  default = "0"
}

variable "resource_group" {
  default = ""
}

variable "vnet" {
  default = ""
}

variable "admin_username" {
  default = ""
}

variable "admin_password" {
  default = ""
}

variable "server_config" {
  description = "overreading server_config values."
  type        = map(any)
  default     = {}
}


variable "default_server_config" {
  description = "Map of project names to configuration."
  type        = map(any)
  default = {
    cloud_init_file_prefix = "metadata/apt/ubuntu-k8s-master_"
    image_version          = "latest",
    image_sku              = "20_04-lts",
    image_offer            = "0001-com-ubuntu-server-focal",
    image_publisher        = "Canonical",
    disk_type              = "Standard_LRS",
    disk_size_gb           = 20,
    instances              = 1
    vm_size                = "Standard_B2s",
    hostname               = "bastion"
    vnet_addr              = "10.1.0.0"
  }
}

variable "tags" {
  description = "Map of project names to configuration."
  type        = map(any)
  default     = {}
}

variable "default_tags" {
  description = "Map of project names to configuration."
  type        = map(any)
  default = {
    environment = "dev"
  }
}
