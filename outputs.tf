# outputs.tf - ce qu'on expose après le terraform apply

output "resource_group_name" {
  description = "Nom du resource group déployé"
  value       = azurerm_resource_group.main.name
}

output "function_app_url" {
  description = "URL de la Function App (endpoint pour uploader des images)"
  value       = module.compute.function_app_url
}

output "storage_account_name" {
  description = "Nom du storage account"
  value       = module.storage.storage_account_name
}

output "images_container_name" {
  description = "Container Blob pour déposer les images"
  value       = module.storage.images_container_name
}

output "results_container_name" {
  description = "Container Blob pour récupérer les résultats OCR"
  value       = module.storage.results_container_name
}

output "vision_endpoint" {
  description = "Endpoint Azure AI Vision"
  value       = module.cognitive_service.vision_endpoint
}

output "app_insights_connection_string" {
  description = "Connection string Application Insights pour le monitoring"
  value       = module.monitoring.connection_string
  sensitive   = true
}

output "key_vault_uri" {
  description = "URI du Key Vault"
  value       = module.cognitive_service.key_vault_uri
}
