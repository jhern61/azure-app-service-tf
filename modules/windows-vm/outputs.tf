output "vm_ids" {
  description = "Map of VM IDs"
  value = {
    for k, v in azurerm_virtual_machine.vm : k => v.id
  }
}

output "vm_private_ips" {
  description = "Map of VM private IP addresses"
  value = {
    for k, v in azurerm_network_interface.vm_nic : k => v.private_ip_address
  }
}

output "vm_identities" {
  description = "Map of VM managed identities"
  value = {
    for k, v in azurerm_virtual_machine.vm : k => v.identity[0]
  }
}

output "sql_vm_ids" {
  description = "Map of SQL VM IDs"
  value = {
    for k, v in azurerm_mssql_virtual_machine.sql_vm : k => v.virtual_machine_id
  }
}

output "availability_set_ids" {
  description = "Map of availability set IDs"
  value = {
    for k, v in azurerm_availability_set.vm_avset : k => v.id
  }
}
