output "ansible01_public_ip" {
  value = azurerm_public_ip.ansible01.ip_address
}

output "dc01_private_ip" {
  value = azurerm_network_interface.dc01.private_ip_address
}

output "app01_private_ip" {
  value = azurerm_network_interface.app01.private_ip_address
}

output "ansible01_private_ip" {
  value = azurerm_network_interface.ansible01.private_ip_address
}