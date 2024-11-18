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

variable "key_vault_name" {
  description = "Name of the Key Vault"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for private endpoint"
  type        = string
}

variable "private_dns_zone_name" {
  description = "Name of the private DNS zone for Key Vault"
  type        = string
  default     = "privatelink.vaultcore.azure.net"
}

variable "app_service_principal_ids" {
  description = "List of App Service principal IDs that need access to the Key Vault"
  type        = list(string)
  default     = []
}
