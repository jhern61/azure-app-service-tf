output "service_plan_ids" {
  description = "Map of service plan IDs"
  value       = { for k, v in azurerm_service_plan.plans : k => v.id }
}

output "app_service_ids" {
  description = "Map of app service IDs"
  value       = { for k, v in azurerm_windows_web_app.apps : k => v.id }
}

output "app_service_names" {
  description = "Map of app service names"
  value       = { for k, v in azurerm_windows_web_app.apps : k => v.name }
}

output "app_service_default_hostnames" {
  description = "Map of app service default hostnames"
  value       = { for k, v in azurerm_windows_web_app.apps : k => v.default_hostname }
}

output "app_service_identities" {
  description = "Map of app service managed identities"
  value       = { for k, v in azurerm_windows_web_app.apps : k => v.identity[0] }
}
