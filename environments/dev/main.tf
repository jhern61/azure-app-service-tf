

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

module "keyvault" {
  source = "../../modules/keyvault"

  key_vaults = {
    kv1 = {
      location              = "East US"
      resource_group_name   = "rg1"
      tenant_id             = "tenant-id"
      private_dns_zone_name = "privatelink.vaultcore.azure.net"
      subnet_id             = "/subscriptions/xxx/resourceGroups/xxx/providers/Microsoft.Network/virtualNetworks/vnet/subnets/subnet1"
      environment           = "dev"
      product               = "xyz"
    }
    kv2 = {
      location              = "West Europe"
      resource_group_name   = "rg2"
      tenant_id             = "tenant-id"
      private_dns_zone_name = "privatelink.vaultcore.azure.net"
      subnet_id             = "/subscriptions/xxx/resourceGroups/xxx/providers/Microsoft.Network/virtualNetworks/vnet/subnets/subnet2"
      environment           = "prod"
      product               = "abc"
    }
  }
}

module "nat_gateway" {
  source = "../../modules/nat-gateway"

  resource_group_name = azurerm_resource_group.rg.name
  location           = local.location

  nat_gateways = {
    "main" = {
      name = "ng-${local.environment}-${local.location}-01"
      subnet_ids = [
        module.vnet.subnet_ids["snet-app-service"],
        module.vnet.subnet_ids["snet-private-endpoints"]
      ]
      idle_timeout_in_minutes = 10
      zones                  = ["1", "2", "3"]
      tags                   = local.tags
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
