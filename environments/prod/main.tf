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

resource "azurerm_resource_group" "rg_dr" {
  count    = var.enable_geo_redundancy ? 1 : 0
  name     = "rg-appservice-${local.environment}-dr"
  location = var.dr_location
  tags     = local.tags
}

module "vnet" {
  source = "../../modules/vnet"

  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  environment         = local.environment
  vnet_name           = "vnet-appservice-${local.environment}"
  vnet_address_space  = ["10.2.0.0/16"] # Different address space from dev/qa

  subnet_configurations = {
    "snet-app-gateway" = {
      address_prefixes = ["10.2.0.0/24"]
    }
    "snet-app-service" = {
      address_prefixes                          = ["10.2.1.0/24"]
      delegation                                = { "delegation" = ["Microsoft.Web/serverFarms"] }
      private_endpoint_network_policies_enabled = true
      service_endpoints                         = ["Microsoft.Web"]
    }
    "snet-private-endpoints" = {
      address_prefixes                          = ["10.2.2.0/24"]
      private_endpoint_network_policies_enabled = true
    }
    "snet-vm" = {
      address_prefixes                          = ["10.2.3.0/24"]
      private_endpoint_network_policies_enabled = true
    }
  }
}

module "vnet_dr" {
  count  = var.enable_geo_redundancy ? 1 : 0
  source = "../../modules/vnet"

  resource_group_name = azurerm_resource_group.rg_dr[0].name
  location            = var.dr_location
  environment         = "${local.environment}-dr"
  vnet_name           = "vnet-appservice-${local.environment}-dr"
  vnet_address_space  = ["10.3.0.0/16"]

  subnet_configurations = {
    "snet-app-gateway" = {
      address_prefixes = ["10.3.0.0/24"]
    }
    "snet-app-service" = {
      address_prefixes                          = ["10.3.1.0/24"]
      delegation                                = { "delegation" = ["Microsoft.Web/serverFarms"] }
      private_endpoint_network_policies_enabled = true
      service_endpoints                         = ["Microsoft.Web"]
    }
    "snet-private-endpoints" = {
      address_prefixes                          = ["10.3.2.0/24"]
      private_endpoint_network_policies_enabled = true
    }
    "snet-vm" = {
      address_prefixes                          = ["10.3.3.0/24"]
      private_endpoint_network_policies_enabled = true
    }
  }
}

module "keyvault" {
  for_each = {
    primary = {
      name = "kv-appservice1-${local.environment}"
    }
    secondary = {
      name = "kv-appservice2-${local.environment}"
    }
  }

  source = "../../modules/keyvault"

  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  environment         = local.environment
  key_vault_name      = each.value.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  subnet_id           = module.vnet.subnet_ids["snet-private-endpoints"]
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
      sku_name    = "P1" # Premium tier for production
      max_size_gb = 256  # Larger size for production
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
      name     = "asp-appservice1-${local.environment}"
      sku_name = "P3v2"  # Higher SKU for production
    }
    "plan2" = {
      name     = "asp-appservice2-${local.environment}"
      sku_name = "P1v2"  # Different SKU for other workloads
    }
  }

  key_vault_id = module.keyvault["primary"].key_vault_id
  vnet_integration_subnet_id = module.vnet.subnet_ids["snet-app-service"]

  app_services = {
    "app1" = {
      name          = "app-service1-${local.environment}"
      service_plan  = "plan1"
      subnet_id     = module.vnet.subnet_ids["snet-private-endpoints"]
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
      slots = {
        staging = {
          name      = "staging"
          subnet_id = module.vnet.subnet_ids["snet-private-endpoints"]
          app_settings = {
            "WEBSITE_DNS_SERVER"     = "168.63.129.16"
            "WEBSITE_VNET_ROUTE_ALL" = "1"
          }
        }
      }
    }
    "app2" = {
      name          = "app-service2-${local.environment}"
      service_plan  = "plan2"
      subnet_id     = module.vnet.subnet_ids["snet-private-endpoints"]
      app_settings = {
        "WEBSITE_DNS_SERVER"     = "168.63.129.16"
        "WEBSITE_VNET_ROUTE_ALL" = "1"
      }
    }
  }
}

module "app_service_dr" {
  count  = var.enable_geo_redundancy ? 1 : 0
  source = "../../modules/app-service"

  resource_group_name = azurerm_resource_group.rg_dr[0].name
  location            = var.dr_location
  environment         = "${local.environment}-dr"

  service_plans = {
    "plan1" = {
      name     = "asp-appservice1-${local.environment}-dr"
      sku_name = "P3v2"
    }
  }

  key_vault_id = module.keyvault["primary"].key_vault_id
  vnet_integration_subnet_id = module.vnet_dr[0].subnet_ids["snet-app-service"]

  app_services = {
    "app1" = {
      name          = "app-service1-${local.environment}-dr"
      service_plan  = "plan1"
      subnet_id     = module.vnet_dr[0].subnet_ids["snet-private-endpoints"]
      app_settings = {
        "WEBSITE_DNS_SERVER"     = "168.63.129.16"
        "WEBSITE_VNET_ROUTE_ALL" = "1"
      }
      connection_strings = {
        "DefaultConnection" = {
          type  = "SQLAzure"
          value = "Server=tcp:${module.sql_server_dr[0].sql_server_fqdn},1433;Database=${module.sql_server_dr[0].database_names["db1"]};Authentication=Active Directory Default;"
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

  app_gateway_name = "agw-appservice-${local.environment}"
  subnet_id        = module.vnet.subnet_ids["snet-app-gateway"]

  ssl_certificate_name     = "example-cert"
  ssl_certificate_data     = filebase64(var.ssl_certificate_path)
  ssl_certificate_password = var.ssl_certificate_password

  backend_address_pools = {
    "app1-pool" = {
      name = "app1-pool"
      fqdns = concat(
        [module.app_service.app_service_default_hostnames["app1"]],
        var.enable_geo_redundancy ? [module.app_service_dr[0].app_service_default_hostnames["app1"]] : []
      )
    }
  }

  backend_http_settings = {
    "app1-https" = {
      name                  = "app1-https"
      cookie_based_affinity = "Enabled" # Enable affinity for production
      port                  = 443
      protocol              = "Https"
      request_timeout       = 30
      host_name             = module.app_service.app_service_default_hostnames["app1"]
    }
  }

  http_listeners = {
    "app1-listener" = {
      name        = "app1-listener"
      host_name   = "app1.${var.app_gateway_domain}"
      require_sni = true
    }
  }

  request_routing_rules = {
    "app1-rule" = {
      name                       = "app1-rule"
      rule_type                  = "Basic"
      http_listener_name         = "app1-listener"
      backend_address_pool_name  = "app1-pool"
      backend_http_settings_name = "app1-https"
      priority                   = 100
    }
  }
}

module "app_gateway_dr" {
  count  = var.enable_geo_redundancy ? 1 : 0
  source = "../../modules/app-gateway"

  resource_group_name = azurerm_resource_group.rg_dr[0].name
  location            = var.dr_location
  environment         = "${local.environment}-dr"

  app_gateway_name = "agw-appservice-${local.environment}-dr"
  subnet_id        = module.vnet_dr[0].subnet_ids["snet-app-gateway"]

  ssl_certificate_name     = "example-cert"
  ssl_certificate_data     = filebase64(var.ssl_certificate_path)
  ssl_certificate_password = var.ssl_certificate_password

  backend_address_pools = {
    "app1-pool" = {
      name  = "app1-pool"
      fqdns = [module.app_service_dr[0].app_service_default_hostnames["app1"]]
    }
  }

  backend_http_settings = {
    "app1-https" = {
      name                  = "app1-https"
      cookie_based_affinity = "Enabled"
      port                  = 443
      protocol              = "Https"
      request_timeout       = 30
      host_name             = module.app_service_dr[0].app_service_default_hostnames["app1"]
    }
  }

  http_listeners = {
    "app1-listener" = {
      name        = "app1-listener"
      host_name   = "app1-dr.${var.app_gateway_domain}"
      require_sni = true
    }
  }

  request_routing_rules = {
    "app1-rule" = {
      name                       = "app1-rule"
      rule_type                  = "Basic"
      http_listener_name         = "app1-listener"
      backend_address_pool_name  = "app1-pool"
      backend_http_settings_name = "app1-https"
      priority                   = 100
    }
  }
}

module "virtual_machines" {
  source = "../../modules/vm"

  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  environment         = local.environment
  subnet_id           = module.vnet.subnet_ids["snet-vm"]
  key_vault_id        = module.keyvault["primary"].key_vault_id
  admin_username      = var.vm_admin_username
  admin_password      = var.vm_admin_password

  availability_sets = {
    "sql-set" = {
      name                         = "as-sql-${local.environment}"
      platform_fault_domain_count  = 2
      platform_update_domain_count = 5
    }
    "app-set" = {
      name                         = "as-app-${local.environment}"
      platform_fault_domain_count  = 2
      platform_update_domain_count = 5
    }
  }

  virtual_machines = {
    "sqlvm1" = {
      name             = "vm-sql-01-${local.environment}"
      size             = "Standard_D4s_v3"
      os_disk_size_gb  = 256
      os_disk_type     = "Premium_LRS"
      publisher        = "MicrosoftSQLServer"
      offer            = "SQL2019-WS2019"
      sku              = "Enterprise"
      availability_set = "sql-set"
      is_sql_server    = true
      data_disks = {
        "data" = {
          name    = "vm-sql-01-data-disk1"
          size_gb = 512
          lun     = 0
        }
        "log" = {
          name    = "vm-sql-01-log-disk1"
          size_gb = 256
          lun     = 1
        }
      }
      sql_connectivity = {
        sql_license_type      = "AHUB"
        sql_connectivity_type = "PRIVATE"
        sql_port              = 1433
        sql_auth              = true
      }
      tags = {
        Application = "SQL Server"
        Role        = "Database"
      }
    }
    "appvm1" = {
      name             = "vm-app-01-${local.environment}"
      size             = "Standard_D2s_v3"
      publisher        = "MicrosoftWindowsServer"
      offer            = "WindowsServer"
      sku              = "2019-Datacenter"
      availability_set = "app-set"
      data_disks = {
        "data" = {
          name    = "vm-app-01-data-disk1"
          size_gb = 256
          lun     = 0
        }
      }
      tags = {
        Application = "Custom App"
        Role        = "Application Server"
      }
    }
  }
}

module "virtual_machines_dr" {
  count  = var.enable_geo_redundancy ? 1 : 0
  source = "../../modules/vm"

  resource_group_name = azurerm_resource_group.rg_dr[0].name
  location            = var.dr_location
  environment         = "${local.environment}-dr"
  subnet_id           = module.vnet_dr[0].subnet_ids["snet-vm"]
  key_vault_id        = module.keyvault["primary"].key_vault_id
  admin_username      = var.vm_admin_username
  admin_password      = var.vm_admin_password

  availability_sets = {
    "sql-set" = {
      name                         = "as-sql-${local.environment}-dr"
      platform_fault_domain_count  = 2
      platform_update_domain_count = 5
    }
    "app-set" = {
      name                         = "as-app-${local.environment}-dr"
      platform_fault_domain_count  = 2
      platform_update_domain_count = 5
    }
  }

  virtual_machines = {
    "sqlvm1" = {
      name             = "vm-sql-01-${local.environment}-dr"
      size             = "Standard_D4s_v3"
      os_disk_size_gb  = 256
      os_disk_type     = "Premium_LRS"
      publisher        = "MicrosoftSQLServer"
      offer            = "SQL2019-WS2019"
      sku              = "Enterprise"
      availability_set = "sql-set"
      is_sql_server    = true
      data_disks = {
        "data" = {
          name    = "vm-sql-01-data-disk1-dr"
          size_gb = 512
          lun     = 0
        }
        "log" = {
          name    = "vm-sql-01-log-disk1-dr"
          size_gb = 256
          lun     = 1
        }
      }
      sql_connectivity = {
        sql_license_type      = "AHUB"
        sql_connectivity_type = "PRIVATE"
        sql_port              = 1433
        sql_auth              = true
      }
      tags = {
        Application = "SQL Server"
        Role        = "Database"
      }
    }
    appvm1 = {
      name             = "vm-app-01-${local.environment}-dr"
      size             = "Standard_D2s_v3"
      publisher        = "MicrosoftWindowsServer"
      offer            = "WindowsServer"
      sku              = "2019-Datacenter"
      availability_set = "app-set"
      data_disks = {
        "data" = {
          name    = "vm-app-01-data-disk1-dr"
          size_gb = 256
          lun     = 0
        }
      }
      tags = {
        Application = "Custom App"
        Role        = "Application Server"
      }
    }
  }
}

data "azurerm_client_config" "current" {}
