variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "name_prefix"         { type = string }
variable "suffix"              { type = string }
variable "tags"                { type = map(string) }
variable "subnet_id"           { type = string }