variable "elastic_pool_name" {
  description = "Name of the elastic pool"
  type        = string
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
}

variable "sku_name" {
  description = "The name of the SKU, typically BasicPool, StandardPool, or PremiumPool"
  type        = string
}

variable "sku_tier" {
  description = "The tier of the SKU, typically Basic, Standard, or Premium"
  type        = string
}

variable "sku_family" {
  description = "The family of hardware Gen4 or Gen5"
  type        = string
}

variable "sku_capacity" {
  description = "The scale up/out capacity, representing server's compute units"
  type        = number
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
