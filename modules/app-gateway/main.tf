resource "azurerm_public_ip" "agw_pip" {
  name                = "${var.app_gateway_name}-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                = "Standard"

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_application_gateway" "agw" {
  name                = var.app_gateway_name
  resource_group_name = var.resource_group_name
  location            = var.location

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = var.subnet_id
  }

  frontend_port {
    name = "https-port"
    port = var.frontend_port
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.agw_pip.id
  }

  ssl_certificate {
    name     = var.ssl_certificate_name
    data     = var.ssl_certificate_data
    password = var.ssl_certificate_password
  }

  dynamic "backend_address_pool" {
    for_each = var.backend_address_pools
    content {
      name         = backend_address_pool.value.name
      fqdns        = backend_address_pool.value.fqdns
      ip_addresses = backend_address_pool.value.ip_addresses
    }
  }

  dynamic "backend_http_settings" {
    for_each = var.backend_http_settings
    content {
      name                  = backend_http_settings.value.name
      cookie_based_affinity = backend_http_settings.value.cookie_based_affinity
      port                 = backend_http_settings.value.port
      protocol             = backend_http_settings.value.protocol
      request_timeout      = backend_http_settings.value.request_timeout
      host_name            = backend_http_settings.value.host_name
    }
  }

  dynamic "http_listener" {
    for_each = var.http_listeners
    content {
      name                           = http_listener.value.name
      frontend_ip_configuration_name = "frontend-ip-config"
      frontend_port_name            = "https-port"
      protocol                      = "Https"
      ssl_certificate_name          = var.ssl_certificate_name
      host_name                     = http_listener.value.host_name
      require_sni                   = http_listener.value.require_sni
    }
  }

  dynamic "request_routing_rule" {
    for_each = var.request_routing_rules
    content {
      name                       = request_routing_rule.value.name
      rule_type                 = request_routing_rule.value.rule_type
      http_listener_name        = request_routing_rule.value.http_listener_name
      backend_address_pool_name = request_routing_rule.value.backend_address_pool_name
      backend_http_settings_name = request_routing_rule.value.backend_http_settings_name
      priority                  = request_routing_rule.value.priority
    }
  }

  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }

  tags = {
    Environment = var.environment
  }
}
