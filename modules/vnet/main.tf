resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_subnet" "subnets" {
  for_each = var.subnet_configurations

  name                 = each.key
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = each.value.address_prefixes

  service_endpoints = each.value.service_endpoints

  # private_endpoint_network_policies_enabled     = each.value.private_endpoint_network_policies_enabled
  private_link_service_network_policies_enabled = each.value.private_link_service_network_policies_enabled

  dynamic "delegation" {
    for_each = each.value.delegation != null ? each.value.delegation : {}
    content {
      name = delegation.key
      service_delegation {
        name    = delegation.value[0]
        actions = length(delegation.value) > 1 ? slice(delegation.value, 1, length(delegation.value)) : []
      }
    }
  }
}

resource "azurerm_network_security_group" "vm_subnet_nsg" {
  name                = "nsg-vm-subnet-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow inbound traffic from Azure Bastion
  security_rule {
    name                       = "AllowHttpsInBound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  # Allow SQL Server traffic from App subnet
  security_rule {
    name                       = "Allow-SQL-AppSubnet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "10.2.1.0/24" # App subnet CIDR
    destination_address_prefix = "*"
  }

  # Allow necessary outbound traffic
  security_rule {
    name                       = "Allow-Internet-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "80"] # HTTPS and HTTP
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  # Deny all other inbound traffic
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = var.environment
  }
}

# Associate the NSG with the VM subnet
resource "azurerm_subnet_network_security_group_association" "vm_subnet_nsg" {
  subnet_id                 = azurerm_subnet.subnets["snet-vm"].id
  network_security_group_id = azurerm_network_security_group.vm_subnet_nsg.id
}

# NAT Gateway Public IP
resource "azurerm_public_ip" "natgw_ip" {
  name                = "pip-natgw-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                = "Standard"
  zones              = ["1"]

  tags = {
    Environment = var.environment
  }
}

# NAT Gateway for App Services subnet
resource "azurerm_nat_gateway" "app_natgw" {
  name                = "natgw-app-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"
  zones               = ["1"]

  tags = {
    Environment = var.environment
  }
}

# Associate NAT Gateway with its public IP
resource "azurerm_nat_gateway_public_ip_association" "app_natgw_ip" {
  nat_gateway_id       = azurerm_nat_gateway.app_natgw.id
  public_ip_address_id = azurerm_public_ip.natgw_ip.id
}

# Associate NAT Gateway with App Services subnet
resource "azurerm_subnet_nat_gateway_association" "app_subnet_natgw" {
  subnet_id      = azurerm_subnet.subnets["snet-app-service"].id
  nat_gateway_id = azurerm_nat_gateway.app_natgw.id
}
