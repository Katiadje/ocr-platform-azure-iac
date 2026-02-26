# modules/cognitive_service/main.tf
# Azure AI Vision (OCR) + Key Vault pour stocker la clé de l'API

data "azurerm_client_config" "current" {}

# Key Vault pour centraliser les secrets
resource "azurerm_key_vault" "main" {
  name                = "kv-${var.name_prefix}-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # soft delete activé, on peut récupérer les secrets supprimés par erreur
  soft_delete_retention_days = 7
  purge_protection_enabled   = false # mettre true en prod

  # accès réseau restreint au subnet + IP locale pour Terraform
  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [var.subnet_id]
    ip_rules                   = ["46.193.70.49"]
  }

  tags = var.tags
}

# politique d'accès pour Terraform lui-même (pour pouvoir créer les secrets)
resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get", "List", "Set", "Delete", "Purge", "Recover"
  ]
}

# le service cognitif Azure AI Vision pour l'OCR
resource "azurerm_cognitive_account" "vision" {
  name                  = "cog-vision-${var.name_prefix}-${var.suffix}"
  location              = var.location
  resource_group_name   = var.resource_group_name
  kind                  = "ComputerVision"
  sku_name              = "S1" # F0 gratuit mais limité, S1 pour avoir du volume
  custom_subdomain_name = "cog-vision-${var.name_prefix}-${var.suffix}"

  # pas d'accès réseau public direct
  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    virtual_network_rules {
      subnet_id = var.subnet_id
    }
  }

  tags = var.tags
}

# stocker la clé de l'API Vision dans le Key Vault (jamais en clair dans le code !)
resource "azurerm_key_vault_secret" "vision_key" {
  name         = "vision-api-key"
  value        = azurerm_cognitive_account.vision.primary_access_key
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.terraform]
}