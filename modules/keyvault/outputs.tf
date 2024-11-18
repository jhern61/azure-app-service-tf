output "key_vault_ids" {
  description = "Map of key vault IDs"
  value       = { for k, v in azurerm_key_vault.kv : k => v.id }
}

output "key_vault_uris" {
  description = "Map of key vault URIs"
  value       = { for k, v in azurerm_key_vault.kv : k => v.vault_uri }
}

output "key_vault_names" {
  description = "Map of key vault names"
  value       = { for k, v in azurerm_key_vault.kv : k => v.name }
}

output "private_endpoint_ids" {
  description = "Map of private endpoint IDs"
  value       = { for k, v in azurerm_private_endpoint.kv_pe : k => v.id }
}

output "private_dns_zone_ids" {
  description = "Map of private DNS zone IDs"
  value       = { for k, v in azurerm_private_dns_zone.kv_zone : k => v.id }
}
