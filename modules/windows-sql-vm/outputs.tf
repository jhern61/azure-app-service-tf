output "vm_ids" {
  description = "Map of VM names to their IDs"
  value = {
    for k, v in azurerm_windows_virtual_machine.vm : k => v.id
  }
}

output "vm_private_ips" {
  description = "Map of VM names to their private IP addresses"
  value = {
    for k, v in azurerm_network_interface.vm_nic : k => v.private_ip_address
  }
}

output "vm_public_ips" {
  description = "Map of VM names to their public IP addresses, if any"
  value = {
    for k, v in azurerm_public_ip.vm_pip : k => v.ip_address
  }
}

output "vm_identities" {
  description = "Map of VM names to their managed identities"
  value = {
    for k, v in azurerm_windows_virtual_machine.vm : k => {
      principal_id = v.identity[0].principal_id
      tenant_id    = v.identity[0].tenant_id
    }
  }
}

output "sql_server_fqdns" {
  description = "Map of VM names to their SQL Server FQDNs"
  value = {
    for k, v in azurerm_windows_virtual_machine.vm : k => v.private_ip_address
  }
}
