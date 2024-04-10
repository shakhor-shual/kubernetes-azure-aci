variable "default_resource_group" {
  description = "Map of project names to configuration."
  type        = map(any)
  default = {
    location     = "uksouth"
    name_prefix  = "shual-AKS-ACI"
    vnet_cidr    = "10.0.0.0/8"
    subnet_cidr  = "10.240.0.0/16"
    virtual_cidr = "10.241.0.0/16"
  }
}

variable "resource_group" {
  type    = map(any)
  default = {}
}

variable "tags" {
  type    = map(any)
  default = {}
}

variable "default_tags" {
  type = map(any)
  default = {
    environment = "dev"
  }
}

variable "bastions-list" {
  description = "Map of project names to configuration."
  type        = map(any)
  default = {
    uksouth-group = {
      cloud_init_file_prefix = "metadata/apt/ubuntu-k8s-master_"
      image_version          = "latest",
      image_sku              = "20_04-lts",
      image_offer            = "0001-com-ubuntu-server-focal",
      image_publisher        = "Canonical",
      disk_type              = "Standard_LRS",
      disk_size_gb           = 20,
      instances              = 1,
      vm_size                = "Standard_B2s",
      location               = "uksouth"
      hostname               = "master"
      vnet_addr              = "10.1.0.0/16"
    },
    ukwest-group = {
      cloud_init_file_prefix = "metadata/apt/ubuntu-k8s-master_"
      image_version          = "latest",
      image_sku              = "20_04-lts",
      image_offer            = "0001-com-ubuntu-server-focal",
      image_publisher        = "Canonical",
      disk_type              = "Standard_LRS",
      disk_size_gb           = 20,
      instances              = 1,
      vm_size                = "Standard_B2s",
      location               = "ukwest"
      hostname               = "master"
      vnet_addr              = "10.0.0.0/16"
    }
  }
}

variable "group_primary" {
  default = "ukwest-group"
}

variable "node-pool" {
  description = "Map of project names to configuration."
  type        = map(any)
  default = {
    uksouth-group = {
      cloud_init_file_prefix = "metadata/apt/ubuntu-k8s-node_"
      image_version          = "latest",
      image_sku              = "20_04-lts",
      image_offer            = "0001-com-ubuntu-server-focal",
      image_publisher        = "Canonical",
      disk_type              = "Standard_LRS",
      disk_size_gb           = 20,
      instances              = 1,
      vm_size                = "Standard_B2ms",
      location               = "uksouth"
      hostname               = "node-uksouth"
      vnet_addr              = "10.1.0.0/16"
    },
    ukwest-group = {
      cloud_init_file_prefix = "metadata/apt/ubuntu-k8s-node_"
      image_version          = "latest",
      image_sku              = "20_04-lts",
      image_offer            = "0001-com-ubuntu-server-focal",
      image_publisher        = "Canonical",
      disk_type              = "Standard_LRS",
      disk_size_gb           = 20,
      instances              = 1,
      vm_size                = "Standard_B2ms",
      location               = "ukwest"
      hostname               = "node-ukwest"
      vnet_addr              = "10.0.0.0/16"
    },
  }
}

variable "prefix" {
  default     = "rg"
  description = "The prefix used for all resources in this example"
}

variable "location" {
  default     = "ukwest"
  description = "The Azure location where all resources in this example should be created"
}

