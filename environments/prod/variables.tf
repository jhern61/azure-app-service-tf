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

# Windows VM Variables
variable "windows_admin_username" {
  description = "Admin username for Windows VMs"
  type        = string
  default     = "winadmin"
}

variable "windows_admin_password" {
  description = "Admin password for Windows VMs"
  type        = string
  sensitive   = true
}

variable "windows_vms" {
  description = "Map of Windows VMs to create"
  type = map(object({
    name                = string
    size                = string
    os_disk_size_gb    = optional(number, 128)
    os_disk_type       = optional(string, "Premium_LRS")
    publisher          = string
    offer              = string
    sku                = string
    version            = optional(string, "latest")
    zones              = optional(list(string))
    availability_set   = optional(string)
    custom_data        = optional(string)
    data_disks = optional(map(object({
      name                 = string
      size_gb             = number
      storage_account_type = string
      lun                 = number
    })))
    backup_policy_id = optional(string)
    tags            = optional(map(string))
  }))
  default = {}
}

variable "windows_availability_sets" {
  description = "Map of availability sets for Windows VMs"
  type = map(object({
    name                         = string
    platform_fault_domain_count  = optional(number, 2)
    platform_update_domain_count = optional(number, 5)
  }))
  default = {}
}

# Linux VM Variables
variable "linux_admin_username" {
  description = "Admin username for Linux VMs"
  type        = string
  default     = "linuxadmin"
}

variable "linux_ssh_public_key" {
  description = "SSH public key for Linux VM authentication"
  type        = string
}

variable "linux_vms" {
  description = "Map of Linux VMs to create"
  type = map(object({
    name                = string
    size                = string
    os_disk_size_gb    = optional(number, 64)
    os_disk_type       = optional(string, "Premium_LRS")
    publisher          = string
    offer              = string
    sku                = string
    version            = optional(string, "latest")
    zones              = optional(list(string))
    availability_set   = optional(string)
    custom_data        = optional(string)
    data_disks = optional(map(object({
      name                 = string
      size_gb             = number
      storage_account_type = string
      lun                 = number
    })))
    backup_policy_id = optional(string)
    tags            = optional(map(string))
  }))
  default = {}
}

variable "linux_availability_sets" {
  description = "Map of availability sets for Linux VMs"
  type = map(object({
    name                         = string
    platform_fault_domain_count  = optional(number, 2)
    platform_update_domain_count = optional(number, 5)
  }))
  default = {}
}

# DR Region VM Variables
variable "windows_vms_dr" {
  description = "Map of Windows VMs to create in DR region"
  type = map(object({
    name                = string
    size                = string
    os_disk_size_gb    = optional(number, 128)
    os_disk_type       = optional(string, "Premium_LRS")
    publisher          = string
    offer              = string
    sku                = string
    version            = optional(string, "latest")
    zones              = optional(list(string))
    availability_set   = optional(string)
    custom_data        = optional(string)
    data_disks = optional(map(object({
      name                 = string
      size_gb             = number
      storage_account_type = string
      lun                 = number
    })))
    backup_policy_id = optional(string)
    tags            = optional(map(string))
  }))
  default = {}
}

variable "linux_vms_dr" {
  description = "Map of Linux VMs to create in DR region"
  type = map(object({
    name                = string
    size                = string
    os_disk_size_gb    = optional(number, 64)
    os_disk_type       = optional(string, "Premium_LRS")
    publisher          = string
    offer              = string
    sku                = string
    version            = optional(string, "latest")
    zones              = optional(list(string))
    availability_set   = optional(string)
    custom_data        = optional(string)
    data_disks = optional(map(object({
      name                 = string
      size_gb             = number
      storage_account_type = string
      lun                 = number
    })))
    backup_policy_id = optional(string)
    tags            = optional(map(string))
  }))
  default = {}
}

variable "windows_availability_sets_dr" {
  description = "Map of availability sets for Windows VMs in DR region"
  type = map(object({
    name                         = string
    platform_fault_domain_count  = optional(number, 2)
    platform_update_domain_count = optional(number, 5)
  }))
  default = {}
}

variable "linux_availability_sets_dr" {
  description = "Map of availability sets for Linux VMs in DR region"
  type = map(object({
    name                         = string
    platform_fault_domain_count  = optional(number, 2)
    platform_update_domain_count = optional(number, 5)
  }))
  default = {}
}