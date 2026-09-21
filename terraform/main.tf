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

# ---------------------------------------------------------
# Resource Group
# ---------------------------------------------------------

resource "azurerm_resource_group" "adlab" {
  name     = var.resource_group_name
  location = var.location
}

# ---------------------------------------------------------
# Networking
# ---------------------------------------------------------

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

# ---------------------------------------------------------
# Public IP - ONLY for the Ansible controller
# ---------------------------------------------------------

resource "azurerm_public_ip" "ansible01" {
  name                = "pip-ansible01"
  location            = azurerm_resource_group.adlab.location
  resource_group_name = azurerm_resource_group.adlab.name

  allocation_method = "Static"
  sku               = "Standard"
}

# ---------------------------------------------------------
# NSG - Ansible Controller
# Allow SSH from your specified public IP/CIDR
# ---------------------------------------------------------

resource "azurerm_network_security_group" "ansible01" {
  name                = "nsg-ansible01"
  location            = azurerm_resource_group.adlab.location
  resource_group_name = azurerm_resource_group.adlab.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_source_cidr
    destination_address_prefix = "*"
  }
}

# ---------------------------------------------------------
# NSG - Windows Servers
# Only allow WinRM from ANSIBLE01
# ---------------------------------------------------------

resource "azurerm_network_security_group" "windows" {
  name                = "nsg-windows"
  location            = azurerm_resource_group.adlab.location
  resource_group_name = azurerm_resource_group.adlab.name

  security_rule {
    name                       = "Allow-WinRM-From-Ansible"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5985"
    source_address_prefix      = "10.10.1.6/32"
    destination_address_prefix = "*"
  }
}

# ---------------------------------------------------------
# NIC - DC01
# ---------------------------------------------------------

resource "azurerm_network_interface" "dc01" {
  name                = "nic-dc01"
  location            = azurerm_resource_group.adlab.location
  resource_group_name = azurerm_resource_group.adlab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.servers.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.10.1.4"
  }
}

resource "azurerm_network_interface_security_group_association" "dc01" {
  network_interface_id      = azurerm_network_interface.dc01.id
  network_security_group_id = azurerm_network_security_group.windows.id
}

# ---------------------------------------------------------
# NIC - APP01
# ---------------------------------------------------------

resource "azurerm_network_interface" "app01" {
  name                = "nic-app01"
  location            = azurerm_resource_group.adlab.location
  resource_group_name = azurerm_resource_group.adlab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.servers.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.10.1.5"
  }
}

resource "azurerm_network_interface_security_group_association" "app01" {
  network_interface_id      = azurerm_network_interface.app01.id
  network_security_group_id = azurerm_network_security_group.windows.id
}

# ---------------------------------------------------------
# NIC - ANSIBLE01
# ---------------------------------------------------------

resource "azurerm_network_interface" "ansible01" {
  name                = "nic-ansible01"
  location            = azurerm_resource_group.adlab.location
  resource_group_name = azurerm_resource_group.adlab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.servers.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.10.1.6"
    public_ip_address_id          = azurerm_public_ip.ansible01.id
  }
}

resource "azurerm_network_interface_security_group_association" "ansible01" {
  network_interface_id      = azurerm_network_interface.ansible01.id
  network_security_group_id = azurerm_network_security_group.ansible01.id
}

# ---------------------------------------------------------
# DC01 - Windows Server
# ---------------------------------------------------------

resource "azurerm_windows_virtual_machine" "dc01" {
  name                = "DC01"
  computer_name       = "DC01"
  resource_group_name = azurerm_resource_group.adlab.name
  location            = azurerm_resource_group.adlab.location
  size                = var.windows_vm_size

  admin_username = var.windows_admin_username
  admin_password = var.windows_admin_password

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

# Bootstrap WinRM for Ansible
resource "azurerm_virtual_machine_extension" "dc01_winrm" {
  name                 = "enable-winrm"
  virtual_machine_id   = azurerm_windows_virtual_machine.dc01.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Bypass -Command \"Enable-PSRemoting -Force; Set-NetFirewallRule -DisplayGroup 'Windows Remote Management' -Enabled True\""
  })
}

# ---------------------------------------------------------
# APP01 - Windows Server
# ---------------------------------------------------------

resource "azurerm_windows_virtual_machine" "app01" {
  name                = "APP01"
  computer_name       = "APP01"
  resource_group_name = azurerm_resource_group.adlab.name
  location            = azurerm_resource_group.adlab.location
  size                = var.windows_vm_size

  admin_username = var.windows_admin_username
  admin_password = var.windows_admin_password

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

resource "azurerm_virtual_machine_extension" "app01_winrm" {
  name                 = "enable-winrm"
  virtual_machine_id   = azurerm_windows_virtual_machine.app01.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Bypass -Command \"Enable-PSRemoting -Force; Set-NetFirewallRule -DisplayGroup 'Windows Remote Management' -Enabled True\""
  })
}

# ---------------------------------------------------------
# ANSIBLE01 - Linux Controller
# ---------------------------------------------------------

resource "azurerm_linux_virtual_machine" "ansible01" {
  name                = "ANSIBLE01"
  computer_name       = "ansible01"
  resource_group_name = azurerm_resource_group.adlab.name
  location            = azurerm_resource_group.adlab.location
  size                = var.linux_vm_size

  admin_username = var.linux_admin_username

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.ansible01.id
  ]

  admin_ssh_key {
    username   = var.linux_admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOF
    #cloud-config
    package_update: true
    packages:
      - python3
      - python3-pip
      - python3-venv
      - git

    runcmd:
      - python3 -m venv /opt/ansible
      - /opt/ansible/bin/pip install --upgrade pip
      - /opt/ansible/bin/pip install ansible pywinrm
      - /opt/ansible/bin/ansible-galaxy collection install ansible.windows
      - ln -s /opt/ansible/bin/ansible /usr/local/bin/ansible
      - ln -s /opt/ansible/bin/ansible-playbook /usr/local/bin/ansible-playbook
      - ln -s /opt/ansible/bin/ansible-galaxy /usr/local/bin/ansible-galaxy
  EOF
  )
}