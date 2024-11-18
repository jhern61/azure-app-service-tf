resource "azurerm_key_vault" "kv" {
  for_each = var.key_vaults

  name                = "kv-${each.value.product}-${each.value.environment}"
  location            = each.value.location
  resource_group_name = each.value.resource_group_name
  tenant_id          = each.value.tenant_id
  sku_name           = each.value.sku_name

  enable_rbac_authorization = each.value.enable_rbac_authorization
  purge_protection_enabled  = each.value.purge_protection_enabled

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = {
    Environment = each.value.environment
    Product     = each.value.product
  }
}

resource "azurerm_private_endpoint" "kv_pe" {
  for_each = var.key_vaults

  name                = "pe-${azurerm_key_vault.kv[each.key].name}"
  location            = each.value.location
  resource_group_name = each.value.resource_group_name
  subnet_id           = each.value.subnet_id

  private_service_connection {
    name                           = "psc-${azurerm_key_vault.kv[each.key].name}"
    private_connection_resource_id = azurerm_key_vault.kv[each.key].id
    is_manual_connection          = false
    subresource_names            = ["vault"]
  }

  private_dns_zone_group {
    name                 = "keyvault-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv_zone[each.key].id]
  }
}

resource "azurerm_private_dns_zone" "kv_zone" {
  for_each = var.key_vaults

  name                = each.value.private_dns_zone_name
  resource_group_name = each.value.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv_zone_link" {
  for_each = var.key_vaults

  name                  = "link-${azurerm_key_vault.kv[each.key].name}"
  resource_group_name   = each.value.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.kv_zone[each.key].name
  virtual_network_id    = split("/subnets/", each.value.subnet_id)[0]
}

# Add access policies for App Services if needed
resource "azurerm_key_vault_access_policy" "app_service_policies" {
  count = length(var.app_service_principal_ids)

  key_vault_id = values(azurerm_key_vault.kv)[0].id
  tenant_id    = values(var.key_vaults)[0].tenant_id
  object_id    = var.app_service_principal_ids[count.index]

  secret_permissions = [
    "Get",
    "List"
  ]
}
