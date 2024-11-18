resource "azurerm_mssql_server" "sql_server" {
  name                         = var.server_name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = var.administrator_login
  administrator_login_password = var.administrator_login_password
  minimum_tls_version         = "1.2"

  public_network_access_enabled = false

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_mssql_database" "databases" {
  for_each = var.databases

  name           = each.value.name
  server_id      = azurerm_mssql_server.sql_server.id
  sku_name       = each.value.sku_name
  max_size_gb    = each.value.max_size_gb

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_private_endpoint" "sql_pe" {
  name                = "${var.server_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.server_name}-privateserviceconnection"
    private_connection_resource_id = azurerm_mssql_server.sql_server.id
    is_manual_connection          = false
    subresource_names            = ["sqlServer"]
  }

  private_dns_zone_group {
    name                 = "sqlserver-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql_zone.id]
  }
}

resource "azurerm_private_dns_zone" "sql_zone" {
  name                = var.private_dns_zone_name
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_zone_link" {
  name                  = "${var.server_name}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.sql_zone.name
  virtual_network_id    = split("/subnets/", var.subnet_id)[0]
}

# Virtual Network Rules for allowed subnets
resource "azurerm_mssql_virtual_network_rule" "vnet_rules" {
  count = length(var.allowed_subnet_ids)

  name      = "sql-vnet-rule-${count.index}"
  server_id = azurerm_mssql_server.sql_server.id
  subnet_id = var.allowed_subnet_ids[count.index]
}
