output "vision_endpoint" {
  description = "Endpoint HTTP de l'API Azure AI Vision"
  value       = azurerm_cognitive_account.vision.endpoint
}

output "vision_key_secret_id" {
  description = "URI du secret Key Vault qui contient la clé Vision"
  value       = azurerm_key_vault_secret.vision_key.id
}

output "key_vault_id" {
  value = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}
