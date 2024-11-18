resource "azurerm_service_plan" "plans" {
  for_each = var.service_plans

  name                = each.value.name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = var.os_type
  sku_name            = each.value.sku_name

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_windows_web_app" "apps" {
  for_each = var.app_services

  name                = each.value.name
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.plans[each.value.service_plan].id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = true
    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v6.0"
    }
  }

  virtual_network_subnet_id = var.vnet_integration_subnet_id

  app_settings = merge(
    each.value.app_settings != null ? each.value.app_settings : {},
    var.vnet_integration_subnet_id != null ? {
      "WEBSITE_DNS_SERVER"     = "168.63.129.16"
      "WEBSITE_VNET_ROUTE_ALL" = "1"
    } : {}
  )

  dynamic "connection_string" {
    for_each = each.value.connection_strings != null ? each.value.connection_strings : {}
    content {
      name  = connection_string.key
      type  = connection_string.value.type
      value = connection_string.value.value
    }
  }

  tags = {
    Environment = var.environment
  }
}

# Deployment slots for each app service
resource "azurerm_windows_web_app_slot" "app_slots" {
  for_each = {
    for pair in flatten([
      for app_key, app in var.app_services : [
        for slot_key, slot in coalesce(app.slots, {}) : {
          id          = "${app_key}.${slot_key}"
          app_key     = app_key
          slot_key    = slot_key
          slot_config = slot
        }
      ]
    ]) : pair.id => pair
  }

  name           = each.value.slot_config.name
  app_service_id = azurerm_windows_web_app.apps[each.value.app_key].id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = true
    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v6.0"
    }
  }

  virtual_network_subnet_id = var.vnet_integration_subnet_id

  app_settings = merge(
    each.value.slot_config.app_settings != null ? each.value.slot_config.app_settings : {},
    var.vnet_integration_subnet_id != null ? {
      "WEBSITE_DNS_SERVER"     = "168.63.129.16"
      "WEBSITE_VNET_ROUTE_ALL" = "1"
    } : {}
  )

  tags = {
    Environment = var.environment
  }
}

# Private Endpoints for each app service
resource "azurerm_private_endpoint" "app_pe" {
  for_each = var.app_services

  name                = "${each.value.name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = each.value.subnet_id

  private_service_connection {
    name                           = "${each.value.name}-privateserviceconnection"
    private_connection_resource_id = azurerm_windows_web_app.apps[each.key].id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }

  private_dns_zone_group {
    name                 = "appservice-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.app_zone.id]
  }
}

# Private Endpoints for each slot
resource "azurerm_private_endpoint" "slot_pe" {
  for_each = {
    for pair in flatten([
      for app_key, app in var.app_services : [
        for slot_key, slot in coalesce(app.slots, {}) : {
          id          = "${app_key}.${slot_key}"
          app_key     = app_key
          slot_key    = slot_key
          slot_config = slot
        }
      ]
    ]) : pair.id => pair
  }

  name                = "${each.value.slot_config.name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = each.value.slot_config.subnet_id

  private_service_connection {
    name                           = "${each.value.slot_config.name}-privateserviceconnection"
    private_connection_resource_id = azurerm_windows_web_app_slot.app_slots[each.key].id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }

  private_dns_zone_group {
    name                 = "appservice-slot-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.app_zone.id]
  }
}

resource "azurerm_private_dns_zone" "app_zone" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "app_zone_link" {
  name                  = "app-service-${var.environment}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.app_zone.name
  virtual_network_id    = split("/subnets/", var.vnet_integration_subnet_id)[0]
}

# Add Key Vault access policy for each app service
resource "azurerm_key_vault_access_policy" "app_policies" {
  for_each = var.app_services

  key_vault_id = var.key_vault_id
  tenant_id    = azurerm_windows_web_app.apps[each.key].identity[0].tenant_id
  object_id    = azurerm_windows_web_app.apps[each.key].identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# Add Key Vault access policy for each slot
resource "azurerm_key_vault_access_policy" "slot_policies" {
  for_each = {
    for pair in flatten([
      for app_key, app in var.app_services : [
        for slot_key, slot in coalesce(app.slots, {}) : {
          id          = "${app_key}.${slot_key}"
          app_key     = app_key
          slot_key    = slot_key
          slot_config = slot
        }
      ]
    ]) : pair.id => pair
  }

  key_vault_id = var.key_vault_id
  tenant_id    = azurerm_windows_web_app_slot.app_slots[each.key].identity[0].tenant_id
  object_id    = azurerm_windows_web_app_slot.app_slots[each.key].identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}
