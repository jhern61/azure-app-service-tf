variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus2"
}

variable "dr_location" {
  description = "Disaster Recovery Azure region"
  type        = string
  default     = "westus2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
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

variable "enable_geo_redundancy" {
  description = "Enable geo-redundancy for applicable services"
  type        = bool
  default     = true
}

variable "vm_admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureadmin"
}

variable "vm_admin_password" {
  description = "Admin password for VMs"
  type        = string
  sensitive   = true
}