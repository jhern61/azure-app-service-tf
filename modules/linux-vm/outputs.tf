output "vm_ids" {
  description = "Map of VM names to their IDs"
  value = {
    for k, v in azurerm_linux_virtual_machine.vm : k => v.id
  }
}

output "vm_private_ips" {
  description = "Map of VM names to their private IP addresses"
  value = {
    for k, v in azurerm_network_interface.vm_nic : k => v.private_ip_address
  }
}

output "vm_identities" {
  description = "Map of VM names to their managed identities"
  value = {
    for k, v in azurerm_linux_virtual_machine.vm : k => {
      principal_id = v.identity[0].principal_id
      tenant_id    = v.identity[0].tenant_id
    }
  }
}
