variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet where VMs will be deployed"
  type        = string
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
}

variable "admin_password" {
  description = "Admin password for VMs"
  type        = string
  sensitive   = true
}

variable "key_vault_id" {
  description = "ID of the Key Vault for storing VM secrets"
  type        = string
}

variable "virtual_machines" {
  description = "Map of VMs to create"
  type = map(object({
    name                = string
    size                = string
    os_disk_size_gb    = optional(number, 128)
    os_disk_type       = optional(string, "Premium_LRS")
    publisher          = string
    offer             = string
    sku               = string
    version           = optional(string, "latest")
    zones             = optional(list(string))
    availability_set  = optional(string)
    data_disks = optional(map(object({
      name            = string
      size_gb         = number
      storage_account_type = optional(string, "Premium_LRS")
      create_option   = optional(string, "Empty")
      lun             = number
    })))
    backup_policy_id = optional(string)
    tags             = optional(map(string))
    custom_data      = optional(string)
    is_sql_server    = optional(bool, false)
    sql_connectivity = optional(object({
      sql_license_type = string
      sql_connectivity_type = string
      sql_port = number
      sql_auth = bool
    }))
  }))
}

variable "availability_sets" {
  description = "Map of availability sets to create"
  type = map(object({
    name                = string
    platform_fault_domain_count = optional(number, 2)
    platform_update_domain_count = optional(number, 5)
  }))
  default = {}
}

variable "network_security_groups" {
  description = "Map of NSGs to create with their rules"
  type = map(object({
    name = string
    rules = map(object({
      name                       = string
      priority                   = number
      direction                  = string
      access                     = string
      protocol                   = string
      source_port_range         = string
      destination_port_range    = string
      source_address_prefix     = string
      destination_address_prefix = string
    }))
  }))
  default = {}
}

variable "vm_nsg_associations" {
  description = "Map of VM names to NSG names for association"
  type = map(string)
  default = {}
}
