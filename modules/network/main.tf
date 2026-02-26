# modules/network/main.tf
# tout ce qui concerne le réseau : VNet, subnets, NSG

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.name_prefix}-${var.suffix}"
  address_space       = var.address_space
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# subnet pour les functions
resource "azurerm_subnet" "functions" {
  name                 = "snet-functions-${var.name_prefix}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_prefixes["functions"]]

  # délégation requise pour les Azure Functions avec intégration VNet
  delegation {
    name = "delegation-functions"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }

  service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.CognitiveServices"]
}

# subnet pour les services cognitifs / storage
resource "azurerm_subnet" "services" {
  name                 = "snet-services-${var.name_prefix}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_prefixes["services"]]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.CognitiveServices"]
}

# NSG pour le subnet functions - on bloque tout ce qui est pas nécessaire
resource "azurerm_network_security_group" "functions" {
  name                = "nsg-functions-${var.name_prefix}-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # autoriser HTTPS sortant vers Azure
  security_rule {
    name                       = "allow-https-outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }

  # bloquer tout le reste en sortie
  security_rule {
    name                       = "deny-all-outbound"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "functions" {
  subnet_id                 = azurerm_subnet.functions.id
  network_security_group_id = azurerm_network_security_group.functions.id
}
