# variables.tf - toutes les variables configurables du projet

variable "environment" {
  description = "Environnement de déploiement (dev ou prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "L'environnement doit être 'dev' ou 'prod'."
  }
}

variable "location" {
  description = "Région Azure pour déployer les ressources"
  type        = string
  default     = "westeurope"
}

variable "vnet_address_space" {
  description = "Plage d'adresses IP du réseau virtuel"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_prefixes" {
  description = "Préfixes des sous-réseaux"
  type        = map(string)
  default = {
    functions = "10.0.1.0/24"
    services  = "10.0.2.0/24"
  }
}
