output "dc01_public_ip" {
  value = azurerm_public_ip.dc01.ip_address
}

output "app01_public_ip" {
  value = azurerm_public_ip.app01.ip_address
}