output "nat_gateway_ids" {
  description = "Map of NAT Gateway IDs"
  value       = { for k, v in azurerm_nat_gateway.nat : k => v.id }
}

output "nat_gateway_public_ips" {
  description = "Map of NAT Gateway public IP addresses"
  value       = { for k, v in azurerm_public_ip.nat : k => v.ip_address }
}

output "nat_gateway_public_ip_ids" {
  description = "Map of NAT Gateway public IP IDs"
  value       = { for k, v in azurerm_public_ip.nat : k => v.id }
}
