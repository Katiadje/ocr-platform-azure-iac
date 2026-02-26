output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "subnet_id" {
  description = "ID du subnet functions (utilisé par compute et storage)"
  value       = azurerm_subnet.functions.id
}

output "services_subnet_id" {
  value = azurerm_subnet.services.id
}
