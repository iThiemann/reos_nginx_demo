############################################################
# Provider + basic setup
############################################################
terraform {
  required_version = ">= 1.5.7"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

############################################################
# Resource Group
############################################################
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

############################################################
# Virtual Network + Subnet
############################################################
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.project_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.project_name}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

############################################################
# Network Security Group (allow SSH + HTTP)
############################################################
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.project_name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # allow SSH from anywhere (you can restrict to your IP)
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # allow HTTP so we can see nginx
  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

############################################################
# Public IP
############################################################
resource "azurerm_public_ip" "public_ip" {
  name                = "${var.project_name}-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

############################################################
# Network Interface
############################################################
resource "azurerm_network_interface" "nic" {
  name                = "${var.project_name}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# associate NSG -> NIC
resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

############################################################
# Cloud-init for nginx "hello world"
# This installs nginx and drops a custom index.html
############################################################
locals {
  cloud_init = <<-EOF
    #cloud-config
    package_update: true
    packages:
      - nginx
    write_files:
      - path: /var/www/html/index.html
        permissions: '0644'
        content: |
          <html>
          <head><title>NGINX on Azure</title></head>
          <body style="font-family: sans-serif;">
            <h1>Hello from NGINX on Azure!</h1>
            <p>Deployed with Terraform 🚀</p>
          </body>
          </html>
    runcmd:
      - systemctl enable nginx
      - systemctl restart nginx
  EOF
}

############################################################
# Linux VM
############################################################
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${var.project_name}-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_B1s" # small & cheap, change if needed
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  # use latest Ubuntu LTS
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # choose SSH or password. SSH is preferred.
  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key)
  }

  computer_name                   = "${var.project_name}-vm"
  disable_password_authentication = true

  # pass cloud-init
  custom_data = base64encode(local.cloud_init)

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "${var.project_name}-osdisk"
  }
}

