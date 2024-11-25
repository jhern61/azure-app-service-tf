variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
}

variable "nat_gateways" {
  description = "Map of NAT Gateway configurations"
  type = map(object({
    name                    = string
    sku_name               = optional(string)
    idle_timeout_in_minutes = optional(number)
    zones                  = optional(list(string))
    subnet_ids             = list(string)
    tags                   = optional(map(string))
  }))
}

locals {
  subnet_associations = flatten([
    for nat_key, nat in var.nat_gateways : [
      for subnet_id in nat.subnet_ids : {
        nat_key   = nat_key
        subnet_id = subnet_id
      }
    ]
  ])
}
