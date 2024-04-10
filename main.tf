
provider "azurerm" {
  features {}
}

locals {
  resource_group = merge(var.default_resource_group, var.resource_group)
  tags           = merge(var.default_tags, var.tags)
  firewall_name  = "my-firewall"
  routing        = "REGIONAL"
  mask_net       = "16"
  mask_subnet    = "24"
  network_name   = "${var.prefix}-vpc"
  network_cidr   = "10.0.0.0/16"
  sub0_name      = "${local.network_name}-sub_bastion"
  sub0_cidr      = "10.0.101.0/24"
  sub1_name      = "${local.network_name}-sub_fw"
  sub1_cidr      = "10.0.102.0/24"
  sub2_name      = "${local.network_name}-sub_kube"
  sub2_cidr      = "10.0.0.0/24"
}

resource "azurerm_resource_group" "cluster-group" {
  name     = "${local.resource_group.name_prefix}-cluster_main-rg"
  location = local.resource_group.location
  tags     = local.tags
}

resource "random_string" "azustring" {
  length  = 16
  special = false
  upper   = false
  numeric = false
}

# Storage account to hold diag data from VMs and Azure Resources
resource "azurerm_storage_account" "storage-acc" {
  name                     = random_string.azustring.result
  resource_group_name      = azurerm_resource_group.cluster-group.name
  location                 = azurerm_resource_group.cluster-group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.tags
}

# Route Table for Azure Virtual Network and Server Subnet
resource "azurerm_virtual_network" "cluster-vnet" {
  name                = "${local.resource_group.name_prefix}-Vnet"
  resource_group_name = azurerm_resource_group.cluster-group.name
  location            = azurerm_resource_group.cluster-group.location
  address_space       = [local.resource_group.vnet_cidr]
  dns_servers         = ["1.1.1.1", "8.8.8.8"]
  tags                = local.tags
}

resource "azurerm_subnet" "cluster-subnet" {
  name                 = "${local.resource_group.name_prefix}-AKS-Subnet"
  resource_group_name  = azurerm_resource_group.cluster-group.name
  virtual_network_name = azurerm_virtual_network.cluster-vnet.name
  address_prefixes     = [local.resource_group.subnet_cidr]
}

resource "azurerm_subnet" "virtual-subnet" {
  name                 = "${local.resource_group.name_prefix}-virtual-Subnet"
  resource_group_name  = azurerm_resource_group.cluster-group.name
  virtual_network_name = azurerm_virtual_network.cluster-vnet.name
  address_prefixes     = [local.resource_group.virtual_cidr]

  delegation {
    name = "aciDelegation"
    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# create app & service principal account for cluster
data "azuread_client_config" "current" {}

resource "azuread_application" "aks-manage-app" {
  display_name = "aks-manage-app"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "aks-principal" {
  application_id               = azuread_application.aks-manage-app.application_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal_password" "aks-principal" {
  service_principal_id = azuread_service_principal.aks-principal.object_id
}

resource "azurerm_role_assignment" "example" {
  scope                = azurerm_virtual_network.cluster-vnet.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.aks-principal.id #data.azurerm_client_config.current.object_id
}

output "aks-principal" {
  value     = azuread_service_principal_password.aks-principal
  sensitive = true
}

# create AKS ckuster with virtual nodes pool in ACI
# the same similar in az cli looks like:
/* 
az aks create \
    --resource-group AKSResourceGroup \
    --name AKSTestCluster \
    --node-count 1 \
    --network-plugin azure \
    --service-cidr 10.0.0.0/16 \
    --dns-service-ip 10.0.0.10 \
    --docker-bridge-address 172.17.0.1/16 \
    --vnet-subnet-id <subnetId>  \
    --service-principal <appId> \ \
    --client-secret <password>
    --generate-ssh-keys 
*/

resource "azurerm_kubernetes_cluster" "aci-cluster" {
  name                = "shual-aks1"
  location            = azurerm_resource_group.cluster-group.location
  resource_group_name = azurerm_resource_group.cluster-group.name
  node_resource_group = "${local.resource_group.name_prefix}-cluster_node-rg"
  dns_prefix          = "shual-aks"

  service_principal {
    client_id     = azuread_service_principal.aks-principal.application_id
    client_secret = azuread_service_principal_password.aks-principal.value
  }

  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size        = "Standard_D2_v2"
    vnet_subnet_id = azurerm_subnet.cluster-subnet.id
  }

  aci_connector_linux {
    subnet_name = "${local.resource_group.name_prefix}-virtual-Subnet"
  }

  network_profile {
    network_plugin     = "azure"
    dns_service_ip     = "10.0.0.10"
    docker_bridge_cidr = "172.17.0.1/16"
    service_cidr       = "10.0.0.0/16"
  }
  depends_on = [azurerm_subnet.virtual-subnet]
}

resource "null_resource" "init-kube-config" {
  provisioner "local-exec" {
    command = "/usr/bin/az aks get-credentials --resource-group ${azurerm_resource_group.cluster-group.name} --name ${azurerm_kubernetes_cluster.aci-cluster.name} --file ~/.kube/config.aks.azure"
  }
  depends_on = [azurerm_kubernetes_cluster.aci-cluster]
}

