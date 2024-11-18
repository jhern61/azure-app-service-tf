resource "azurerm_key_vault" "kv" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_private_endpoint" "kv_pe" {
  name                = "${var.key_vault_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.key_vault_name}-privateserviceconnection"
    private_connection_resource_id = azurerm_key_vault.kv.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "keyvault-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv_zone.id]
  }
}

resource "azurerm_private_dns_zone" "kv_zone" {
  name                = var.private_dns_zone_name
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv_zone_link" {
  name                  = "${var.key_vault_name}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.kv_zone.name
  virtual_network_id    = split("/subnets/", var.subnet_id)[0]
}

# Add access policies for App Services
resource "azurerm_key_vault_access_policy" "app_service_policies" {
  count = length(var.app_service_principal_ids)

  key_vault_id = azurerm_key_vault.kv.id3
  tenant_id    = var.tenant_id
  object_id    = var.app_service_principal_ids[count.index]

  secret_permissions = [
    "Get",
    "List"
  ]
}
