terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  required_version = ">= 1.15.0"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "adlab" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "adlab" {
  name                = "vnet-adlab"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.adlab.location
  resource_group_name = azurerm_resource_group.adlab.name
}

resource "azurerm_subnet" "servers" {
  name                 = "snet-servers"
  resource_group_name  = azurerm_resource_group.adlab.name
  virtual_network_name = azurerm_virtual_network.adlab.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_network_interface" "dc01" {
  name                = "nic-dc01"
  location            = azurerm_resource_group.adlab.location
  resource_group_name = azurerm_resource_group.adlab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.servers.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "app01" {
  name                = "nic-app01"
  location            = azurerm_resource_group.adlab.location
  resource_group_name = azurerm_resource_group.adlab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.servers.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "dc01" {
  name                = "DC01"
  computer_name       = "DC01"
  resource_group_name = azurerm_resource_group.adlab.name
  location            = azurerm_resource_group.adlab.location
  size                = var.vm_size

  admin_username = var.admin_username
  admin_password = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.dc01.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_windows_virtual_machine" "app01" {
  name                = "APP01"
  computer_name       = "APP01"
  resource_group_name = azurerm_resource_group.adlab.name
  location            = azurerm_resource_group.adlab.location
  size                = var.vm_size

  admin_username = var.admin_username
  admin_password = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.app01.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}