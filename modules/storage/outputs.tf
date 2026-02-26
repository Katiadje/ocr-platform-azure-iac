output "storage_account_name" {
  value = azurerm_storage_account.main.name
}

output "storage_account_access_key" {
  value     = azurerm_storage_account.main.primary_access_key
  sensitive = true
}

output "storage_account_id" {
  value = azurerm_storage_account.main.id
}

output "images_container_name" {
  value = azurerm_storage_container.images.name
}

output "results_container_name" {
  value = azurerm_storage_container.results.name
}

output "functions_storage_account_name" {
  value = azurerm_storage_account.functions.name
}

output "functions_storage_connection_string" {
  value     = azurerm_storage_account.functions.primary_connection_string
  sensitive = true
}

output "functions_storage_access_key" {
  value     = azurerm_storage_account.functions.primary_access_key
  sensitive = true
}