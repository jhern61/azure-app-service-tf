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

module "windows_vms" {
  source = "../../modules/windows-vm"

  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  environment         = local.environment
  subnet_id           = module.vnet.subnet_ids["snet-app-service"]
  key_vault_id        = module.keyvault.key_vault_ids["kv1"]
  admin_username      = "winadmin"
  admin_password      = "P@ssw0rd1234!" # Note: In production, use key vault secret

  virtual_machines = {
    "vmwin1" = {
      name          = "vmwin-app-${local.environment}-1"
      size          = "Standard_B2s"
      computer_name = "vmwinapp${local.environment}1"
      publisher     = "MicrosoftWindowsServer"
      offer         = "WindowsServer"
      sku           = "2019-Datacenter"
    },
    "vmwin2" = {
      name          = "vmwin-app-${local.environment}-2"
      size          = "Standard_B2s"
      computer_name = "vmwinapp${local.environment}2"
      publisher     = "MicrosoftWindowsServer"
      offer         = "WindowsServer"
      sku           = "2019-Datacenter"
    }
  }

  network_security_groups = {
    "shared_windows_nsg" = {
      name = "nsg-shared-windows-${local.environment}"
      rules = {
        "allow_rdp" = {
          name                       = "allow-rdp"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range         = "*"
          destination_port_range    = "3389"
          source_address_prefix     = "VirtualNetwork"
          destination_address_prefix = "*"
        }
        "allow_winrm" = {
          name                       = "allow-winrm"
          priority                   = 110
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range         = "*"
          destination_port_range    = "5985-5986"
          source_address_prefix     = "VirtualNetwork"
          destination_address_prefix = "*"
        }
      }
    }
  }

  vm_nsg_associations = {
    "vmwin1" = "shared_windows_nsg"
    "vmwin2" = "shared_windows_nsg"
  }

}

module "linux_vms" {
  source = "../../modules/linux-vm"

  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  environment         = local.environment
  subnet_id           = module.vnet.subnet_ids["snet-app-service"]
  admin_username      = "vmadmin"
  ssh_public_key      = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC..." # Replace with your actual SSH public key

  virtual_machines = {
    "vm1" = {
      name          = "vm-app-${local.environment}-1"
      size          = "Standard_B2s"
      computer_name = "vmapp${local.environment}1"
      publisher     = "Canonical"
      offer         = "UbuntuServer"
      sku           = "18.04-LTS"
      data_disks = {
        "data" = {
          name                 = "vm-app-${local.environment}-1-data"
          size_gb             = 100
          storage_account_type = "Premium_LRS"
          lun                 = 0
        },
        "logs" = {
          name                 = "vm-app-${local.environment}-1-logs"
          size_gb             = 50
          storage_account_type = "StandardSSD_LRS"
          lun                 = 1
        },
        "backup" = {
          name                 = "vm-app-${local.environment}-1-backup"
          size_gb             = 200
          storage_account_type = "Standard_LRS"
          lun                 = 2
        }
      }
      tags = {
        Environment     = local.environment
        Role           = "Application"
        CostCenter     = "IT-12345"
        Owner          = "DevOps Team"
        Project        = "WebApp"
        BusinessUnit   = "Digital"
        Criticality    = "Medium"
        SecurityZone   = "Internal"
        Backup        = "Daily"
        PatchGroup    = "Linux-Weekly"
        CreatedBy     = "Terraform"
        CreatedDate   = "2024-12-19"
      }
    }
  }

  network_security_groups = {
    "shared_linux_nsg" = {
      name = "nsg-shared-linux-${local.environment}"
      rules = {
        "allow_ssh" = {
          name                       = "allow-ssh"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range         = "*"
          destination_port_range    = "22"
          source_address_prefix     = "VirtualNetwork"
          destination_address_prefix = "*"
        }
      }
    }
    "web_linux_nsg" = {
      name = "nsg-web-linux-${local.environment}"
      rules = {
        "allow_http" = {
          name                       = "allow-http"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range         = "*"
          destination_port_range    = "80"
          source_address_prefix     = "*"
          destination_address_prefix = "*"
        }
        "allow_https" = {
          name                       = "allow-https"
          priority                   = 110
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range         = "*"
          destination_port_range    = "443"
          source_address_prefix     = "*"
          destination_address_prefix = "*"
        }
      }
    }
  }

  vm_nsg_associations = {
    "vmlinux1" = "shared_linux_nsg"
    "vmlinux2" = "web_linux_nsg"
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
