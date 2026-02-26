# modules/compute/main.tf
# Function App (serverless) avec Managed Identity pour éviter les secrets en dur

# service plan consumption (payer uniquement à l'usage, parfait pour notre use case)
resource "azurerm_service_plan" "main" {
  name                = "asp-${var.name_prefix}-${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "Y1" # plan consumption, gratuit jusqu'à 1M d'exécutions/mois

  tags = var.tags
}

resource "azurerm_linux_function_app" "main" {
  name                       = "func-${var.name_prefix}-${var.suffix}"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  service_plan_id            = azurerm_service_plan.main.id
  storage_account_name       = var.functions_storage_account_name
  storage_account_access_key = var.functions_storage_access_key

  # managed identity system-assigned : pas besoin de gérer des credentials manuellement !
  identity {
    type = "SystemAssigned"
  }

  # VNet integration retirée : pas compatible avec le plan Y1 Consumption

  site_config {
    application_stack {
      python_version = "3.11"
    }
    # toujours actif même sur plan consumption (cold start réduit)
    always_on = false
  }

  app_settings = {
    # connexion au storage pour les triggers blob
    "AzureWebJobsStorage"                   = "DefaultEndpointsProtocol=https;AccountName=${var.storage_account_name};AccountKey=${var.storage_account_access_key}"
    "FUNCTIONS_WORKER_RUNTIME"              = "python"
    "FUNCTIONS_EXTENSION_VERSION"           = "~4"
    "IMAGES_CONTAINER"                      = var.images_container_name
    "RESULTS_CONTAINER"                     = var.results_container_name
    "VISION_ENDPOINT"                       = var.vision_endpoint
    # la clé Vision est récupérée depuis Key Vault via la managed identity
    "VISION_API_KEY"                        = "@Microsoft.KeyVault(SecretUri=${var.vision_key_secret_id})"
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = var.app_insights_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = "InstrumentationKey=${var.app_insights_key}"
    "STORAGE_ACCOUNT_NAME"                  = var.storage_account_name
  }

  tags = var.tags
}

# RBAC : donner accès à la managed identity de la function sur le Key Vault
resource "azurerm_key_vault_access_policy" "function_app" {
  key_vault_id = var.key_vault_id
  tenant_id    = azurerm_linux_function_app.main.identity[0].tenant_id
  object_id    = azurerm_linux_function_app.main.identity[0].principal_id

  # lecture seule sur les secrets (principe du moindre privilège)
  secret_permissions = ["Get", "List"]
}

# RBAC : accès au blob storage (lecture images + écriture résultats)
resource "azurerm_role_assignment" "function_storage_blob" {
  scope                = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}

data "azurerm_subscription" "current" {}