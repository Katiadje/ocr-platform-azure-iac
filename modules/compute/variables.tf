variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "name_prefix"         { type = string }
variable "suffix"              { type = string }
variable "tags"                { type = map(string) }
variable "storage_account_name" { type = string }

variable "storage_account_access_key" {
  type      = string
  sensitive = true
}

variable "functions_storage_account_name" { type = string }

variable "functions_storage_access_key" {
  type      = string
  sensitive = true
}

variable "images_container_name"  { type = string }
variable "results_container_name" { type = string }
variable "vision_endpoint"        { type = string }
variable "vision_key_secret_id"   { type = string }
variable "key_vault_id"           { type = string }

variable "app_insights_key" {
  type      = string
  sensitive = true
}

variable "subnet_id" { type = string }

variable "vision_api_key" {
  type      = string
  sensitive = true
}