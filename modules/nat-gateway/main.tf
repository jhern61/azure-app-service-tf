resource "azurerm_public_ip" "nat" {
  for_each = var.nat_gateways

  name                = "pip-${each.value.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = try(each.value.zones, null)
  tags                = try(each.value.tags, {})
}

resource "azurerm_nat_gateway" "nat" {
  for_each = var.nat_gateways

  name                    = each.value.name
  location               = var.location
  resource_group_name    = var.resource_group_name
  sku_name               = try(each.value.sku_name, "Standard")
  idle_timeout_in_minutes = try(each.value.idle_timeout_in_minutes, 4)
  zones                  = try(each.value.zones, null)
  tags                   = try(each.value.tags, {})
}

resource "azurerm_nat_gateway_public_ip_association" "nat" {
  for_each = var.nat_gateways

  nat_gateway_id       = azurerm_nat_gateway.nat[each.key].id
  public_ip_address_id = azurerm_public_ip.nat[each.key].id
}

resource "azurerm_subnet_nat_gateway_association" "nat" {
  for_each = {
    for assoc in local.subnet_associations : "${assoc.nat_key}.${assoc.subnet_id}" => assoc
  }

  subnet_id      = each.value.subnet_id
  nat_gateway_id = azurerm_nat_gateway.nat[each.value.nat_key].id
}
