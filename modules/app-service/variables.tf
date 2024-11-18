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

variable "service_plans" {
  description = "Map of service plans to create"
  type = map(object({
    name     = string
    sku_name = string
  }))
}

variable "app_services" {
  description = "Map of app services to create"
  type = map(object({
    name           = string
    service_plan   = string
    subnet_id      = string
    app_settings   = optional(map(string))
    connection_strings = optional(map(object({
      type  = string
      value = string
    })))
    slots = optional(map(object({
      name         = string
      subnet_id    = string
      app_settings = optional(map(string))
    })))
  }))
}

variable "os_type" {
  description = "OS type for the App Service Plan"
  type        = string
  default     = "Windows"
}

variable "key_vault_id" {
  description = "ID of the Key Vault for MSI access"
  type        = string
}

variable "vnet_integration_subnet_id" {
  description = "Subnet ID for VNET integration"
  type        = string
  default     = null
}
