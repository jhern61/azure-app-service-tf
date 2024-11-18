variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
}

variable "app_gateway_name" {
  description = "Name of the Application Gateway"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the Application Gateway"
  type        = string
}

variable "backend_address_pools" {
  description = "Map of backend address pools"
  type = map(object({
    name         = string
    fqdns        = list(string)
    ip_addresses = optional(list(string))
  }))
}

variable "frontend_port" {
  description = "Frontend port for the Application Gateway"
  type        = number
  default     = 443
}

variable "ssl_certificate_name" {
  description = "Name of the SSL certificate in Application Gateway"
  type        = string
}

variable "ssl_certificate_data" {
  description = "Base64 encoded SSL certificate data"
  type        = string
  sensitive   = true
}

variable "ssl_certificate_password" {
  description = "Password for the SSL certificate"
  type        = string
  sensitive   = true
}

variable "backend_http_settings" {
  description = "Map of backend HTTP settings"
  type = map(object({
    name                  = string
    cookie_based_affinity = string
    port                 = number
    protocol             = string
    request_timeout      = number
    host_name            = string
  }))
}

variable "http_listeners" {
  description = "Map of HTTP listeners"
  type = map(object({
    name                 = string
    host_name           = string
    require_sni         = bool
  }))
}

variable "request_routing_rules" {
  description = "Map of request routing rules"
  type = map(object({
    name                       = string
    rule_type                 = string
    http_listener_name        = string
    backend_address_pool_name = string
    backend_http_settings_name = string
    priority                  = number
  }))
}
