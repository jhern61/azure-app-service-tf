variable "key_vaults" {
  description = "Map of key vault configurations"
  type = map(object({
    location              = string
    resource_group_name   = string
    tenant_id            = string
    private_dns_zone_name = string
    subnet_id            = string
    environment          = string
    product              = string
    enable_rbac_authorization = optional(bool, false)
    purge_protection_enabled  = optional(bool, true)
    sku_name                 = optional(string, "standard")
  }))
}

variable "app_service_principal_ids" {
  description = "List of App Service principal IDs that need access to the Key Vault"
  type        = list(string)
  default     = []
}
