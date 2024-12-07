locals {
  environment = var.environment
  location    = var.location
  tags = {
    Environment = local.environment
    Terraform   = "true"
  }
}

data "azurerm_client_config" "current" {}

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
    "snet-aks" = {
      address_prefixes                          = ["10.2.4.0/22"]
      private_endpoint_network_policies_enabled = true
      service_endpoints                         = ["Microsoft.ContainerRegistry"]
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
  source = "../../modules/keyvault"

  key_vaults = {
    kv1 = {
      location              = "East US"
      resource_group_name   = "rg1"
      tenant_id             = data.azurerm_client_config.current.tenant_id
      private_dns_zone_name = "privatelink.vaultcore.azure.net"
      subnet_id             = "/subscriptions/xxx/resourceGroups/xxx/providers/Microsoft.Network/virtualNetworks/vnet/subnets/subnet1"
      environment           = "dev"
      product               = "xyz"
    }
    kv2 = {
      location              = "West Europe"
      resource_group_name   = "rg2"
      tenant_id             = data.azurerm_client_config.current.tenant_id
      private_dns_zone_name = "privatelink.vaultcore.azure.net"
      subnet_id             = "/subscriptions/xxx/resourceGroups/xxx/providers/Microsoft.Network/virtualNetworks/vnet/subnets/subnet2"
      environment           = "prod"
      product               = "abc"
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
      sku_name    = "P1" # Premium tier for production
      max_size_gb = 256  # Larger size for production
    }
  }
}

module "sql_server_dr" {
  count  = var.enable_geo_redundancy ? 1 : 0
  source = "../../modules/sql-server"

  resource_group_name          = azurerm_resource_group.rg_dr[0].name
  location                     = var.dr_location
  environment                  = "${local.environment}-dr"
  server_name                  = "sql-appservice-${local.environment}-dr"
  administrator_login          = "sqladmin"
  administrator_login_password = var.sql_admin_password
  subnet_id                    = module.vnet_dr[0].subnet_ids["snet-private-endpoints"]
  allowed_subnet_ids           = [module.vnet_dr[0].subnet_ids["snet-app-service"]]

  databases = {
    "db1" = {
      name        = "appdb1"
      sku_name    = "P1"
      max_size_gb = 256
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
      sku_name = "P3v2" # Higher SKU for production
    }
    "plan2" = {
      name     = "asp-appservice2-${local.environment}"
      sku_name = "P1v2" # Different SKU for other workloads
    }
  }

  key_vault_id               = module.keyvault.key_vault_ids["kv1"]
  vnet_integration_subnet_id = module.vnet.subnet_ids["snet-app-service"]

  app_services = {
    "app1" = {
      name         = "app-service1-${local.environment}"
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
      name         = "app-service2-${local.environment}"
      service_plan = "plan2"
      subnet_id    = module.vnet.subnet_ids["snet-private-endpoints"]
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

  key_vault_id               = module.keyvault.key_vault_ids["kv1"]
  vnet_integration_subnet_id = module.vnet_dr[0].subnet_ids["snet-app-service"]

  app_services = {
    "app1" = {
      name         = "app-service1-${local.environment}-dr"
      service_plan = "plan1"
      subnet_id    = module.vnet_dr[0].subnet_ids["snet-private-endpoints"]
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

module "aks" {
  source = "../../modules/aks"

  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  environment         = local.environment

  clusters = {
    "primary" = {
      name               = "aks-${local.environment}-primary"
      kubernetes_version = "1.26.3"
      vnet_subnet_id     = module.vnet.subnet_ids["snet-aks"]

      system_node_pool = {
        name                = "system"
        vm_size             = "Standard_D4s_v3"
        enable_auto_scaling = true
        node_count          = 1
        min_count           = 1
        max_count           = 3
        os_disk_size_gb     = 128
        max_pods            = 30
      }

      user_node_pools = {
        "general" = {
          vm_size             = "Standard_D4s_v3"
          enable_auto_scaling = true
          node_count          = 2
          min_count           = 2
          max_count           = 5
          os_disk_size_gb     = 128
          max_pods            = 30
          node_labels = {
            "workload-type" = "general"
          }
        }
        "memory" = {
          vm_size             = "Standard_E4s_v3"
          enable_auto_scaling = true
          node_count          = 1
          min_count           = 1
          max_count           = 3
          os_disk_size_gb     = 128
          max_pods            = 30
          node_labels = {
            "workload-type" = "memory-optimized"
          }
        }
      }
    }

    "secondary" = {
      name               = "aks-${local.environment}-secondary"
      kubernetes_version = "1.26.3"
      vnet_subnet_id     = module.vnet.subnet_ids["snet-aks"]

      system_node_pool = {
        name                = "system"
        vm_size             = "Standard_D4s_v3"
        enable_auto_scaling = true
        node_count          = 1
        min_count           = 1
        max_count           = 3
        os_disk_size_gb     = 128
        max_pods            = 30
      }

      user_node_pools = {
        "general" = {
          vm_size             = "Standard_D4s_v3"
          enable_auto_scaling = true
          node_count          = 2
          min_count           = 2
          max_count           = 5
          os_disk_size_gb     = 128
          max_pods            = 30
          node_labels = {
            "workload-type" = "general"
          }
        }
      }
    }
  }

  tags = local.tags
}

# Windows Virtual Machines
module "windows_vms" {
  source = "../../modules/windows-vm"

  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  environment         = local.environment
  subnet_id           = module.vnet.subnet_ids["snet-vm"]
  admin_username      = var.windows_admin_username
  admin_password      = var.windows_admin_password
  virtual_machines    = var.windows_vms
  availability_sets   = var.windows_availability_sets
  key_vault_id        = module.keyvault.key_vault_ids["kv1"]
}

# Linux Virtual Machines
module "linux_vms" {
  source = "../../modules/linux-vm"

  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  environment         = local.environment
  subnet_id           = module.vnet.subnet_ids["snet-vm"]
  admin_username      = var.linux_admin_username
  ssh_public_key      = var.linux_ssh_public_key
  virtual_machines    = var.linux_vms
  availability_sets   = var.linux_availability_sets
}

# DR Region Windows Virtual Machines
module "windows_vms_dr" {
  count  = var.enable_geo_redundancy ? 1 : 0
  source = "../../modules/windows-vm"

  resource_group_name = azurerm_resource_group.rg_dr[0].name
  location            = var.dr_location
  environment         = "${local.environment}-dr"
  subnet_id           = module.vnet_dr[0].subnet_ids["snet-vm"]
  admin_username      = var.windows_admin_username
  admin_password      = var.windows_admin_password
  virtual_machines    = var.windows_vms_dr
  availability_sets   = var.windows_availability_sets_dr
  key_vault_id        = module.keyvault.key_vault_ids["kv1"]
}

# DR Region Linux Virtual Machines
module "linux_vms_dr" {
  count  = var.enable_geo_redundancy ? 1 : 0
  source = "../../modules/linux-vm"

  resource_group_name = azurerm_resource_group.rg_dr[0].name
  location            = var.dr_location
  environment         = "${local.environment}-dr"
  subnet_id           = module.vnet_dr[0].subnet_ids["snet-vm"]
  admin_username      = var.linux_admin_username
  ssh_public_key      = var.linux_ssh_public_key
  virtual_machines    = var.linux_vms_dr
  availability_sets   = var.linux_availability_sets_dr
}
