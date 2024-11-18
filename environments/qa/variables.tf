variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "qa"
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
