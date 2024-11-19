locals {
  environment = var.environment
  location    = var.location
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
  location            = local.location
  environment         = local.environment
  vnet_name           = "vnet-appservice-${local.environment}"
  vnet_address_space  = ["10.1.0.0/16"] # Different address space from dev

  subnet_configurations = {
    "snet-app-gateway" = {
      address_prefixes = ["10.1.0.0/24"]
    }
    "snet-app-service" = {
      address_prefixes                          = ["10.1.1.0/24"]
      delegation                                = { "delegation" = ["Microsoft.Web/serverFarms"] }
      private_endpoint_network_policies_enabled = true
      service_endpoints                         = ["Microsoft.Web"]
    }
    "snet-private-endpoints" = {
      address_prefixes                          = ["10.1.2.0/24"]
      private_endpoint_network_policies_enabled = true
    }
  }
}

module "keyvault" {
  source = "../../modules/keyvault"

  key_vaults = {
    "kv1" = {
      name                  = "kv-${local.environment}-${local.location}-01"
      location              = local.location
      resource_group_name   = azurerm_resource_group.rg.name
      tenant_id             = data.azurerm_client_config.current.tenant_id
      subnet_id             = module.vnet.subnet_ids["snet-private-endpoints"]
      private_dns_zone_name = "privatelink.vaultcore.azure.net"
      environment           = local.environment
      product               = "core"
    }
  }
}

module "sql_server" {
  source = "../../modules/sql-server"

  resource_group_name          = azurerm_resource_group.rg.name
  location                     = local.location
  environment                  = local.environment
  server_name                  = "sql-appservice-${local.environment}"
  administrator_login          = "sqladmin"
  administrator_login_password = var.sql_admin_password
  subnet_id                    = module.vnet.subnet_ids["snet-private-endpoints"]
  allowed_subnet_ids           = [module.vnet.subnet_ids["snet-app-service"]]

  databases = {
    "db1" = {
      name        = "appdb1"
      sku_name    = "S1" # Higher SKU for QA
      max_size_gb = 64   # Larger size for QA
    }
  }
}

module "app_service" {
  source = "../../modules/app-service"

  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  environment         = local.environment

  service_plans = {
    "plan1" = {
      name     = "asp-${local.environment}-${local.location}-01"
      sku_name = "P1v2"
    }
  }

  key_vault_id               = module.keyvault.key_vault_ids["kv1"]
  vnet_integration_subnet_id = module.vnet.subnet_ids["snet-app-service"]

  app_services = {
    "app1" = {
      name         = "app-${local.environment}-${local.location}-01"
      service_plan = "plan1"
      subnet_id    = module.vnet.subnet_ids["snet-private-endpoints"]
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
  location            = local.location
  environment         = local.environment

  app_gateway_name = "agw-${local.environment}-${local.location}-01"
  subnet_id        = module.vnet.subnet_ids["snet-app-gateway"]

  ssl_certificate_name     = "app-cert"
  ssl_certificate_data     = filebase64(var.ssl_certificate_path)
  ssl_certificate_password = var.ssl_certificate_password

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
      path                  = "/"
      port                  = 443
      protocol              = "Https"
      request_timeout       = 30
      probe_name            = "app1-probe"
      host_name             = module.app_service.app_service_default_hostnames["app1"]
    }
  }

  http_listeners = {
    "app1-https" = {
      name                           = "app1-https"
      frontend_ip_configuration_name = "public"
      frontend_port_name             = "port-443"
      protocol                       = "Https"
      ssl_certificate_name           = "app-cert"
      host_name                      = "app1-qa.${var.app_gateway_domain}"
      require_sni                    = true
    }
  }

  request_routing_rules = {
    "app1-rule" = {
      name                       = "app1-rule"
      rule_type                  = "Basic"
      http_listener_name         = "app1-https"
      backend_address_pool_name  = "app1-pool"
      backend_http_settings_name = "app1-https"
      priority                   = 100
    }
  }

}

resource "azurerm_public_ip" "app_gateway" {
  name                = "pip-agw-${local.environment}-${local.location}-01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

data "azurerm_client_config" "current" {}
