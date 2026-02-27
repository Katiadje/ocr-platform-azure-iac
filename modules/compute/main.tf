# modules/compute/main.tf
# Function App (serverless) avec Managed Identity pour éviter les secrets en dur

resource "azurerm_service_plan" "main" {
  name                = "asp-${var.name_prefix}-${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "Y1"

  tags = var.tags
}

resource "azurerm_linux_function_app" "main" {
  name                       = "func-${var.name_prefix}-${var.suffix}"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  service_plan_id            = azurerm_service_plan.main.id
  storage_account_name       = var.functions_storage_account_name
  storage_account_access_key = var.functions_storage_access_key

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.11"
    }
    always_on = false
  }

  app_settings = {
    "AzureWebJobsStorage"                   = "DefaultEndpointsProtocol=https;AccountName=${var.functions_storage_account_name};AccountKey=${var.functions_storage_access_key};EndpointSuffix=core.windows.net"
    "IMAGES_STORAGE_CONNECTION"             = "DefaultEndpointsProtocol=https;AccountName=${var.storage_account_name};AccountKey=${var.storage_account_access_key};EndpointSuffix=core.windows.net"
    "FUNCTIONS_WORKER_RUNTIME"              = "python"
    "FUNCTIONS_EXTENSION_VERSION"           = "~4"
    "IMAGES_CONTAINER"                      = var.images_container_name
    "RESULTS_CONTAINER"                     = var.results_container_name
    "VISION_ENDPOINT"                       = var.vision_endpoint
    "VISION_API_KEY"                        = var.vision_api_key
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = var.app_insights_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = "InstrumentationKey=${var.app_insights_key}"
    "STORAGE_ACCOUNT_NAME"                  = var.storage_account_name
    "WEBSITE_RUN_FROM_PACKAGE"              = "1"
  }

  tags = var.tags
}

resource "azurerm_key_vault_access_policy" "function_app" {
  key_vault_id = var.key_vault_id
  tenant_id    = azurerm_linux_function_app.main.identity[0].tenant_id
  object_id    = azurerm_linux_function_app.main.identity[0].principal_id

  secret_permissions = ["Get", "List"]
}

resource "azurerm_role_assignment" "function_storage_blob" {
  scope                = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}

data "azurerm_subscription" "current" {}
