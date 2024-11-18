output "app_gateway_id" {
  description = "The ID of the Application Gateway"
  value       = azurerm_application_gateway.agw.id
}

output "app_gateway_name" {
  description = "The name of the Application Gateway"
  value       = azurerm_application_gateway.agw.name
}

output "app_gateway_frontend_ip_configuration" {
  description = "The frontend IP configuration of the Application Gateway"
  value       = azurerm_application_gateway.agw.frontend_ip_configuration
}

output "public_ip_address" {
  description = "The public IP address of the Application Gateway"
  value       = azurerm_public_ip.agw_pip.ip_address
}

output "backend_address_pools" {
  description = "Map of backend address pool names to their IDs"
  value       = { for pool in azurerm_application_gateway.agw.backend_address_pool : pool.name => pool.id }
}
