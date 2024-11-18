resource "azurerm_kubernetes_cluster" "aks" {
  for_each            = var.clusters
  name                = each.value.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = coalesce(each.value.dns_prefix, each.value.name)
  kubernetes_version  = each.value.kubernetes_version
  tags               = var.tags

  default_node_pool {
    name                = each.value.system_node_pool.name
    vm_size            = each.value.system_node_pool.vm_size
    enable_auto_scaling = each.value.system_node_pool.enable_auto_scaling
    node_count         = each.value.system_node_pool.node_count
    min_count          = each.value.system_node_pool.min_count
    max_count          = each.value.system_node_pool.max_count
    os_disk_size_gb    = each.value.system_node_pool.os_disk_size_gb
    max_pods           = each.value.system_node_pool.max_pods
    vnet_subnet_id     = each.value.vnet_subnet_id
    type               = "VirtualMachineScaleSets"
    
    tags = merge(var.tags, {
      "nodepool-type" = "system"
      "environment"   = var.environment
      "cluster"       = each.key
    })
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = var.network_plugin
    network_policy = var.network_policy
  }

  azure_policy_enabled = true
  
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks[each.key].id
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  for_each = merge([
    for cluster_key, cluster in var.clusters : {
      for pool_key, pool in cluster.user_node_pools : 
      "${cluster_key}-${pool_key}" => merge(pool, {
        cluster_key = cluster_key
        pool_key    = pool_key
        cluster_id  = azurerm_kubernetes_cluster.aks[cluster_key].id
        subnet_id   = cluster.vnet_subnet_id
      })
    }
  ]...)

  name                  = each.value.pool_key
  kubernetes_cluster_id = each.value.cluster_id
  vm_size              = each.value.vm_size
  enable_auto_scaling   = each.value.enable_auto_scaling
  node_count           = each.value.node_count
  min_count            = each.value.min_count
  max_count            = each.value.max_count
  os_disk_size_gb      = each.value.os_disk_size_gb
  max_pods             = each.value.max_pods
  vnet_subnet_id       = each.value.subnet_id
  node_labels          = each.value.node_labels
  node_taints          = each.value.node_taints

  tags = merge(var.tags, {
    "nodepool-type" = "user"
    "environment"   = var.environment
    "cluster"       = each.value.cluster_key
  })
}

resource "azurerm_log_analytics_workspace" "aks" {
  for_each            = var.clusters
  name                = "log-${each.value.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                = "PerGB2018"
  retention_in_days   = 30

  tags = merge(var.tags, {
    "component" = "monitoring"
    "cluster"   = each.key
  })
}
