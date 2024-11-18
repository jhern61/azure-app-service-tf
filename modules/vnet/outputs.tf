output "vnet_id" {
  description = "The ID of the Virtual Network"
  value       = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  description = "The name of the Virtual Network"
  value       = azurerm_virtual_network.vnet.name
}

output "subnet_ids" {
  description = "Map of subnet names to subnet IDs"
  value       = { for k, v in azurerm_subnet.subnets : k => v.id }
}

output "subnet_names" {
  description = "Map of subnet names"
  value       = { for k, v in azurerm_subnet.subnets : k => v.name }
}

output "nat_gateway_id" {
  description = "The ID of the NAT Gateway"
  value       = azurerm_nat_gateway.app_natgw.id
}

output "nat_gateway_public_ip" {
  description = "The public IP address of the NAT Gateway"
  value       = azurerm_public_ip.natgw_ip.ip_address
}
