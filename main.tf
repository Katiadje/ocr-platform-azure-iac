# main.tf - point d'entrée principal du projet
# on appelle tous les modules depuis ici

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # backend distant pour stocker le state sur Azure (pas en local sinon c'est le bordel en équipe)
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstateocr2026"
    container_name       = "tfstate"
    key                  = "ocr-platform.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

# suffix random pour éviter les conflits de noms globaux
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  # convention de nommage : {ressource}-{projet}-{env}-{suffix}
  suffix      = random_string.suffix.result
  project     = "ocr"
  name_prefix = "${local.project}-${var.environment}"

  # tags obligatoires sur toutes les ressources
  common_tags = {
    project     = "ocr-platform"
    environment = var.environment
    owner       = "m2-iac-group"
    managed_by  = "terraform"
  }
}

# resource group principal
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}-${local.suffix}"
  location = var.location
  tags     = local.common_tags
}

# --- modules ---

module "network" {
  source = "./modules/network"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  name_prefix         = local.name_prefix
  suffix              = local.suffix
  tags                = local.common_tags
  address_space       = var.vnet_address_space
  subnet_prefixes     = var.subnet_prefixes
}

module "storage" {
  source = "./modules/storage"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  name_prefix         = local.name_prefix
  suffix              = local.suffix
  tags                = local.common_tags
  subnet_id           = module.network.subnet_id
}

module "cognitive_service" {
  source = "./modules/cognitive_service"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  name_prefix         = local.name_prefix
  suffix              = local.suffix
  tags                = local.common_tags
  subnet_id           = module.network.subnet_id
}

module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  name_prefix         = local.name_prefix
  suffix              = local.suffix
  tags                = local.common_tags
}

module "compute" {
  source = "./modules/compute"

  resource_group_name            = azurerm_resource_group.main.name
  location                       = var.location
  name_prefix                    = local.name_prefix
  suffix                         = local.suffix
  tags                           = local.common_tags
  storage_account_name           = module.storage.storage_account_name
  storage_account_access_key     = module.storage.storage_account_access_key
  functions_storage_account_name = module.storage.functions_storage_account_name
  functions_storage_access_key   = module.storage.functions_storage_access_key
  images_container_name          = module.storage.images_container_name
  results_container_name         = module.storage.results_container_name
  vision_endpoint                = module.cognitive_service.vision_endpoint
  vision_key_secret_id           = module.cognitive_service.vision_key_secret_id
  vision_api_key                 = module.cognitive_service.vision_api_key
  key_vault_id                   = module.cognitive_service.key_vault_id
  app_insights_key               = module.monitoring.instrumentation_key
  subnet_id                      = module.network.subnet_id
}