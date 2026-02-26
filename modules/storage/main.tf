# modules/storage/main.tf
# storage account + containers blob pour les images et résultats

resource "azurerm_storage_account" "main" {
  # nom sans tirets, max 24 chars, doit être unique globalement
  name                     = "st${replace(var.name_prefix, "-", "")}${var.suffix}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS" # LRS suffisant pour du dev, passer en GRS en prod

  # pas d'accès public aux blobs, mais le firewall réseau est géré par Azure Services
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true
  min_tls_version                 = "TLS1_2"

  # activer le chiffrement (activé par défaut mais on le met explicitement)
  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

# container pour déposer les images à analyser
resource "azurerm_storage_container" "images" {
  name                  = "images-input"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# container pour stocker les résultats OCR (JSON)
resource "azurerm_storage_container" "results" {
  name                  = "ocr-results"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# storage account séparé pour le plan functions (obligatoire)
resource "azurerm_storage_account" "functions" {
  name                     = "stfunc${replace(var.name_prefix, "-", "")}${var.suffix}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  allow_nested_items_to_be_public = false

  tags = var.tags
}