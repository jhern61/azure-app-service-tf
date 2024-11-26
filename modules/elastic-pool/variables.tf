variable "elastic_pool_name" {
  description = "Name of the elastic pool"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{3,63}$", var.elastic_pool_name))
    error_message = "Elastic pool name must be between 3 and 63 characters long and can only contain letters, numbers, and hyphens."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region location"
  type        = string
}

variable "server_name" {
  description = "Name of the SQL server"
  type        = string
}

variable "max_size_gb" {
  description = "The max size of the elastic pool in GB"
  type        = number
  validation {
    condition     = var.max_size_gb >= 50
    error_message = "Max size GB must be at least 50 GB."
  }
}

variable "sku_name" {
  description = "The name of the SKU, typically BasicPool, StandardPool, or PremiumPool"
  type        = string
}

variable "sku_tier" {
  description = "The tier of the SKU, typically Basic, Standard, or Premium"
  type        = string
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku_tier)
    error_message = "SKU tier must be one of: Basic, Standard, or Premium."
  }
}

variable "sku_family" {
  description = "The family of hardware Gen4 or Gen5"
  type        = string
  validation {
    condition     = contains(["Gen4", "Gen5"], var.sku_family)
    error_message = "SKU family must be either Gen4 or Gen5."
  }
}

variable "sku_capacity" {
  description = "The scale up/out capacity, representing server's compute units"
  type        = number
  validation {
    condition     = var.sku_capacity > 0
    error_message = "SKU capacity must be greater than 0."
  }
}

variable "per_database_min_capacity" {
  description = "The minimum capacity all databases are guaranteed"
  type        = number
}

variable "per_database_max_capacity" {
  description = "The maximum capacity any one database can consume"
  type        = number
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
}

variable "tags" {
  description = "A mapping of tags to assign to the resource"
  type        = map(string)
  default     = {}
}
