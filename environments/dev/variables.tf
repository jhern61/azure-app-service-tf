variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "sql_admin_password" {
  description = "SQL Server administrator password"
  type        = string
  sensitive   = true
}

variable "ssl_certificate_path" {
  description = "Path to SSL certificate file"
  type        = string
}

variable "ssl_certificate_password" {
  description = "Password for SSL certificate"
  type        = string
  sensitive   = true
}

variable "app_gateway_domain" {
  description = "Domain for the Application Gateway"
  type        = string
  default     = "example.com"
}

variable "vnet_name" {
  description = "Name of the Virtual Network"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = list(string)
}

variable "subnet_configurations" {
  description = "Map of subnet configurations"
  type = map(object({
    address_prefixes                           = list(string)
    delegation                                 = optional(map(list(string)))
    private_endpoint_network_policies_enabled = optional(bool)
    service_endpoints                         = optional(list(string))
  }))
}

variable "sql_server_name" {
  description = "Name of the SQL Server"
  type        = string
}

variable "sql_administrator_login" {
  description = "SQL Server administrator login"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "databases" {
  description = "Map of database configurations"
  type = map(object({
    name        = string
    sku_name    = string
    max_size_gb = number
  }))
}

variable "key_vaults" {
  description = "Map of key vault configurations"
  type = map(object({
    location              = string
    resource_group_name   = string
    tenant_id             = string
    private_dns_zone_name = string
    subnet_id             = string
    environment          = string
    product             = string
  }))
}

variable "nat_gateways" {
  description = "Map of NAT gateway configurations"
  type = map(object({
    name                    = string
    subnet_ids             = list(string)
    idle_timeout_in_minutes = number
    zones                  = list(string)
    tags                   = map(string)
  }))
}

variable "app_gateway_name" {
  description = "Name of the Application Gateway"
  type        = string
}

variable "ssl_certificate_name" {
  description = "Name of the SSL certificate"
  type        = string
}

variable "ssl_certificate_data" {
  description = "Base64-encoded SSL certificate data"
  type        = string
  sensitive   = true
}

variable "backend_address_pools" {
  description = "Map of backend address pool configurations"
  type = map(object({
    name  = string
    fqdns = list(string)
  }))
}

variable "backend_http_settings" {
  description = "Map of backend HTTP settings configurations"
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
  description = "Map of HTTP listener configurations"
  type = map(object({
    name        = string
    host_name   = string
    require_sni = bool
  }))
}

variable "request_routing_rules" {
  description = "Map of request routing rule configurations"
  type = map(object({
    name                       = string
    rule_type                 = string
    http_listener_name        = string
    backend_address_pool_name = string
    backend_http_settings_name = string
    priority                  = number
  }))
}
