
environment        = "dev"
location           = "francecentral"
vnet_address_space = ["10.0.0.0/16"]

subnet_prefixes = {
  functions = "10.0.1.0/24"
  services  = "10.0.2.0/24"
}
