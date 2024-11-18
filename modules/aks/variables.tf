variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the AKS cluster"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "clusters" {
  description = "Map of AKS cluster configurations"
  type = map(object({
    name                = string
    kubernetes_version  = optional(string, "1.26.3")
    dns_prefix         = optional(string)
    vnet_subnet_id     = string
    system_node_pool   = object({
      name                = string
      vm_size            = string
      enable_auto_scaling = bool
      node_count         = number
      min_count          = optional(number)
      max_count          = optional(number)
      os_disk_size_gb    = optional(number)
      max_pods           = optional(number)
    })
    user_node_pools    = map(object({
      vm_size            = string
      enable_auto_scaling = bool
      node_count         = number
      min_count          = optional(number)
      max_count          = optional(number)
      os_disk_size_gb    = optional(number)
      max_pods           = optional(number)
      node_labels        = optional(map(string))
      node_taints        = optional(list(string))
    }))
  }))
}

variable "network_plugin" {
  description = "Network plugin for AKS (azure or kubenet)"
  type        = string
  default     = "azure"
}

variable "network_policy" {
  description = "Network policy to use (azure or calico)"
  type        = string
  default     = "azure"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
