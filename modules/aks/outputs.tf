output "cluster_ids" {
  description = "Map of AKS cluster IDs"
  value       = { for k, v in azurerm_kubernetes_cluster.aks : k => v.id }
}

output "cluster_names" {
  description = "Map of AKS cluster names"
  value       = { for k, v in azurerm_kubernetes_cluster.aks : k => v.name }
}

output "kube_configs" {
  description = "Map of kubeconfigs for each AKS cluster"
  value       = { for k, v in azurerm_kubernetes_cluster.aks : k => v.kube_config_raw }
  sensitive   = true
}

output "cluster_identities" {
  description = "Map of managed identities for each AKS cluster"
  value = {
    for k, v in azurerm_kubernetes_cluster.aks : k => {
      principal_id = v.identity[0].principal_id
      tenant_id    = v.identity[0].tenant_id
    }
  }
}

output "node_resource_groups" {
  description = "Map of resource groups containing the AKS node pools"
  value       = { for k, v in azurerm_kubernetes_cluster.aks : k => v.node_resource_group }
}

output "log_analytics_workspace_ids" {
  description = "Map of Log Analytics workspace IDs"
  value       = { for k, v in azurerm_log_analytics_workspace.aks : k => v.id }
}
