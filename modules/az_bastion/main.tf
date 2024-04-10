locals {
  server_config = merge(var.default_server_config, var.server_config)
  tags          = merge(var.default_tags, var.tags)
}


# Subnet for bastion, Servers, and Firewall and Route Table Association
resource "azurerm_subnet" "bastion-subnet" {
  virtual_network_name = var.vnet.name
  name                 = "bastion-subnet" //"${local.sub2_name}"
  resource_group_name  = var.resource_group.name
  address_prefixes     = [cidrsubnet("${local.server_config.vnet_addr}", 8, 2)]
}



# Public IP for Bastion
resource "azurerm_public_ip" "bastion-ip" {
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location
  allocation_method   = "Dynamic"
  sku                 = "Basic"

  count = local.server_config.instances
  name  = "bastion-IP-${count.index}"
  tags = {
    environment = "dev"
  }
}

# NSG for bastion Server
resource "azurerm_network_security_group" "bastion-secure" {
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location

  count = local.server_config.instances
  name  = "bastion-NSG-${count.index}"
  security_rule {
    name                       = "SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  tags = var.tags
}

# Nic for bastion Server
resource "azurerm_network_interface" "vm-nic" {
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location

  count = local.server_config.instances
  name  = "bastion-nic-${count.index}"

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.bastion-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion-ip[count.index].id
  }
  tags = var.tags
}

resource "azurerm_network_interface_security_group_association" "vm-nic" {
  count                     = local.server_config.instances
  network_interface_id      = azurerm_network_interface.vm-nic[count.index].id
  network_security_group_id = azurerm_network_security_group.bastion-secure[count.index].id
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

# Bastion VM
resource "azurerm_virtual_machine" "bastion" {
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
  tags       = var.tags
  depends_on = [azurerm_network_interface_security_group_association.vm-nic]
}
