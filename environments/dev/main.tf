locals {
  environment = var.environment
  location    = var.location
  tags = merge(var.tags, {
    Environment = var.environment
    Terraform   = "true"
  })
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

module "vnet" {
  source = "../../modules/vnet"

  resource_group_name   = azurerm_resource_group.rg.name
  location              = var.location
  environment           = var.environment
  vnet_name             = var.vnet_name
  vnet_address_space    = var.vnet_address_space
  subnet_configurations = var.subnet_configurations
}

module "sql_server" {
  source = "../../modules/sql-server"

  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  environment         = var.environment
  server_name         = var.sql_server_name
  administrator_login = var.sql_administrator_login

  administrator_login_password = var.sql_admin_password
  subnet_id                    = module.vnet.subnet_ids["snet-private-endpoints"]
  allowed_subnet_ids           = [module.vnet.subnet_ids["snet-app-service"]]

  databases = var.databases
}

module "keyvault" {
  source = "../../modules/keyvault"

  key_vaults = var.key_vaults
}

module "nat_gateway" {
  source = "../../modules/nat-gateway"

  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location

  nat_gateways = var.nat_gateways
}

module "app_gateway" {
  source = "../../modules/app-gateway"

  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  environment         = var.environment

  app_gateway_name = var.app_gateway_name
  subnet_id        = module.vnet.subnet_ids["snet-app-gateway"]

  # These should be stored in Key Vault and retrieved
  ssl_certificate_name     = var.ssl_certificate_name
  ssl_certificate_data     = var.ssl_certificate_data
  ssl_certificate_password = var.ssl_certificate_password

  backend_address_pools = var.backend_address_pools
  backend_http_settings = var.backend_http_settings
  http_listeners        = var.http_listeners
  request_routing_rules = var.request_routing_rules
}

data "azurerm_client_config" "current" {}
