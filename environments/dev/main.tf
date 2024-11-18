terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

locals {
  environment = "dev"
  location    = "eastus2"
  tags = {
    Environment = local.environment
    Terraform   = "true"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-appservice-${local.environment}"
  location = local.location
  tags     = local.tags
}

module "vnet" {
  source = "../../modules/vnet"

  resource_group_name = azurerm_resource_group.rg.name
  location           = local.location
  environment        = local.environment
  vnet_name          = "vnet-appservice-${local.environment}"
  vnet_address_space = ["10.0.0.0/16"]

  subnet_configurations = {
    "snet-app-gateway" = {
      address_prefixes = ["10.0.0.0/24"]
    }
    "snet-app-service" = {
      address_prefixes                               = ["10.0.1.0/24"]
      delegation                                     = { "delegation" = ["Microsoft.Web/serverFarms"] }
      private_endpoint_network_policies_enabled     = true
      service_endpoints                             = ["Microsoft.Web"]
    }
    "snet-private-endpoints" = {
      address_prefixes                               = ["10.0.2.0/24"]
      private_endpoint_network_policies_enabled     = true
    }
  }
}

module "keyvault" {
  source = "../../modules/keyvault"

  resource_group_name = azurerm_resource_group.rg.name
  location           = local.location
  environment        = local.environment
  key_vault_name     = "kv-appservice-${local.environment}"
  tenant_id          = data.azurerm_client_config.current.tenant_id
  subnet_id          = module.vnet.subnet_ids["snet-private-endpoints"]
}

module "sql_server" {
  source = "../../modules/sql-server"

  resource_group_name  = azurerm_resource_group.rg.name
  location            = local.location
  environment         = local.environment
  server_name         = "sql-appservice-${local.environment}"
  administrator_login = "sqladmin"
  # This should be stored in a secure location and passed as a variable
  administrator_login_password = "P@ssw0rd1234!"
  subnet_id           = module.vnet.subnet_ids["snet-private-endpoints"]
  allowed_subnet_ids  = [module.vnet.subnet_ids["snet-app-service"]]

  databases = {
    "db1" = {
      name        = "appdb1"
      sku_name    = "S0"
      max_size_gb = 32
    }
  }
}

module "app_service" {
  source = "../../modules/app-service"

  resource_group_name = azurerm_resource_group.rg.name
  location           = local.location
  environment        = local.environment
  
  app_service_plan_name = "asp-appservice-${local.environment}"
  key_vault_id         = module.keyvault.key_vault_id
  
  vnet_integration_subnet_id = module.vnet.subnet_ids["snet-app-service"]

  app_services = {
    "app1" = {
      name      = "app-service1-${local.environment}"
      subnet_id = module.vnet.subnet_ids["snet-private-endpoints"]
      app_settings = {
        "WEBSITE_DNS_SERVER"     = "168.63.129.16"
        "WEBSITE_VNET_ROUTE_ALL" = "1"
      }
      connection_strings = {
        "DefaultConnection" = {
          type  = "SQLAzure"
          value = "Server=tcp:${module.sql_server.sql_server_fqdn},1433;Database=${module.sql_server.database_names["db1"]};Authentication=Active Directory Default;"
        }
      }
    }
  }
}

module "app_gateway" {
  source = "../../modules/app-gateway"

  resource_group_name = azurerm_resource_group.rg.name
  location           = local.location
  environment        = local.environment
  
  app_gateway_name = "agw-appservice-${local.environment}"
  subnet_id        = module.vnet.subnet_ids["snet-app-gateway"]

  # These should be stored in Key Vault and retrieved
  ssl_certificate_name     = "example-cert"
  ssl_certificate_data     = filebase64("path/to/certificate.pfx")
  ssl_certificate_password = "certpassword"

  backend_address_pools = {
    "app1-pool" = {
      name  = "app1-pool"
      fqdns = [module.app_service.app_service_default_hostnames["app1"]]
    }
  }

  backend_http_settings = {
    "app1-https" = {
      name                  = "app1-https"
      cookie_based_affinity = "Disabled"
      port                 = 443
      protocol             = "Https"
      request_timeout      = 30
      host_name            = module.app_service.app_service_default_hostnames["app1"]
    }
  }

  http_listeners = {
    "app1-listener" = {
      name       = "app1-listener"
      host_name  = "app1.example.com"
      require_sni = true
    }
  }

  request_routing_rules = {
    "app1-rule" = {
      name                       = "app1-rule"
      rule_type                 = "Basic"
      http_listener_name        = "app1-listener"
      backend_address_pool_name = "app1-pool"
      backend_http_settings_name = "app1-https"
      priority                  = 100
    }
  }
}

data "azurerm_client_config" "current" {}
