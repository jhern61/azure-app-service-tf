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

variable "server_name" {
  description = "Name of the SQL Server"
  type        = string
}

variable "administrator_login" {
  description = "Administrator login for SQL Server"
  type        = string
}

variable "administrator_login_password" {
  description = "Administrator login password for SQL Server"
  type        = string
  sensitive   = true
}

variable "subnet_id" {
  description = "Subnet ID for private endpoint"
  type        = string
}

variable "private_dns_zone_name" {
  description = "Name of the private DNS zone for SQL Server"
  type        = string
  default     = "privatelink.database.windows.net"
}

variable "databases" {
  description = "Map of databases to create"
  type = map(object({
    name      = string
    sku_name  = string
    max_size_gb = number
  }))
  default = {}
}

variable "allowed_subnet_ids" {
  description = "List of subnet IDs allowed to access the SQL Server"
  type        = list(string)
  default     = []
}
