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
  description = "Admin password for Windows VMs"
  type        = string
  sensitive   = true
}

variable "virtual_machines" {
  description = "Map of Windows SQL VMs to create"
  type = map(object({
    name            = string
    size            = string
    os_disk_size_gb = optional(number, 128)
    os_disk_type    = optional(string, "Premium_LRS")
    timezone        = optional(string, "UTC")
    patch_mode      = optional(string, "AutomaticByOS")
    ip_configurations = optional(map(object({
      name                          = string
      subnet_id                     = string
      private_ip_address_allocation = optional(string, "Dynamic")
      private_ip_address            = optional(string)
      primary                       = optional(bool, false)
      create_public_ip              = optional(bool, false)
      public_ip_sku                 = optional(string, "Standard")
      public_ip_allocation          = optional(string, "Static")
      })), {
      "primary" = {
        name                          = "primary"
        subnet_id                     = var.subnet_id
        private_ip_address_allocation = "Dynamic"
        primary                       = true
        create_public_ip              = false
      }
    })
    data_disks = optional(map(object({
      managed_disk_type = string
      create_option     = string
      disk_size_gb      = number
      caching           = string
      lun               = number
    })))
    sql_configuration = object({
      sql_connectivity_port = optional(number, 1433)
      sql_connectivity_type = optional(string, "PRIVATE")
      sql_authentication    = optional(string, "SQL")
      sql_service_account   = optional(string)
      sql_service_password  = optional(string)
      storage_configuration = object({
        disk_type             = optional(string, "Premium_LRS")
        storage_workload_type = optional(string, "GENERAL")
        data_settings = object({
          default_file_path = optional(string, "F:\\data")
          luns              = list(number)
        })
        log_settings = object({
          default_file_path = optional(string, "G:\\log")
          luns              = list(number)
        })
        temp_db_settings = object({
          default_file_path = optional(string, "D:\\tempdb")
          luns              = optional(list(number))
        })
      })
    })
    backup_policy_id = optional(string)
    tags             = optional(map(string))
  }))
}

variable "availability_sets" {
  description = "Map of availability sets to create"
  type = map(object({
    name                         = string
    platform_fault_domain_count  = optional(number, 2)
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
      source_port_range          = string
      destination_port_range     = string
      source_address_prefix      = string
      destination_address_prefix = string
    }))
  }))
  default = {}
}

variable "vm_nsg_associations" {
  description = "Map of VM names to NSG names for association"
  type        = map(string)
  default     = {}
}
