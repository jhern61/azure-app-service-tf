output "app_service_plan_id" {
  description = "The ID of the App Service Plan"
  value       = azurerm_service_plan.plan.id
}

output "app_service_ids" {
  description = "Map of app service names to their IDs"
  value       = { for k, v in azurerm_windows_web_app.apps : k => v.id }
}

output "app_service_names" {
  description = "Map of app service names"
  value       = { for k, v in azurerm_windows_web_app.apps : k => v.name }
}

output "app_service_default_hostnames" {
  description = "Map of app service names to their default hostnames"
  value       = { for k, v in azurerm_windows_web_app.apps : k => v.default_hostname }
}

output "app_service_identities" {
  description = "Map of app service names to their managed identities"
  value       = { for k, v in azurerm_windows_web_app.apps : k => v.identity[0] }
}
