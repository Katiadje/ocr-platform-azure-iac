output "function_app_url" {
  description = "URL publique de la Function App"
  value       = "https://${azurerm_linux_function_app.main.default_hostname}"
}

output "function_app_name" {
  value = azurerm_linux_function_app.main.name
}

output "function_app_identity_principal_id" {
  description = "Principal ID de la managed identity (utile pour RBAC)"
  value       = azurerm_linux_function_app.main.identity[0].principal_id
}
