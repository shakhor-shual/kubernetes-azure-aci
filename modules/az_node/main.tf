

# Route Table for Azure Virtual Network and Server Subnet

locals {
  server_config = merge(var.default_server_config, var.server_config)
  tags          = merge(var.default_tags, var.tags)
}

resource "azurerm_route_table" "v-router" {
  name                          = "AzfwRouteTable"
  resource_group_name           = var.resource_group.name
  location                      = var.resource_group.location
  disable_bgp_route_propagation = false

  route {
    name                   = "AzfwDefaultRoute"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.0.1.4"
  }

  tags = local.tags
}

resource "azurerm_subnet" "nodes-subnet" {
  virtual_network_name = var.vnet.name
  name                 = "nodes-subnet" //"${local.sub2_name}"
  resource_group_name  = var.resource_group.name
  address_prefixes     = [cidrsubnet("${local.server_config.vnet_addr}", 8, 0)]
}

resource "azurerm_subnet_route_table_association" "azurtassoc" {
  route_table_id = azurerm_route_table.v-router.id
  subnet_id      = azurerm_subnet.nodes-subnet.id
}

# Nic for Nodes in ng-1
resource "azurerm_network_interface" "vm-nic" {
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location

  count = local.server_config.instances
  name  = "node-${count.index}-NIC"
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.nodes-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = local.tags
}

# cloud init for Azure
data "template_file" "script" {
  template = file("${local.server_config.cloud_init_file_prefix}cloud-config.yml")
}

# Render a multi-part cloud-init config making use of the part
# above, and other source files
data "template_cloudinit_config" "config" {
  gzip          = true
  base64_encode = true
  # Main cloud-config configuration file.
  part {
    filename     = "cloud-init"
    content_type = "text/cloud-config"
    content      = data.template_file.script.rendered
  }
}

# Node VM in ng-1
resource "azurerm_virtual_machine" "node" {
  resource_group_name           = var.resource_group.name
  location                      = var.resource_group.location
  delete_os_disk_on_termination = true

  count                 = local.server_config.instances
  name                  = "${local.server_config.hostname}-${count.index}"
  vm_size               = local.server_config.vm_size
  network_interface_ids = ["${azurerm_network_interface.vm-nic[count.index].id}"]
  storage_image_reference {
    publisher = local.server_config.image_publisher
    offer     = local.server_config.image_offer
    sku       = local.server_config.image_sku
    version   = local.server_config.image_version
  }
  storage_os_disk {
    name              = "${local.server_config.hostname}-${count.index}-OSDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = local.server_config.disk_type
  }
  os_profile {
    computer_name  = "${local.server_config.hostname}-${count.index}"
    admin_username = var.admin_username
    admin_password = var.admin_password
    custom_data    = data.template_cloudinit_config.config.rendered
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = local.tags
}

