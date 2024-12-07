# Create availability sets if specified
resource "azurerm_availability_set" "vm_avset" {
  for_each = var.availability_sets

  name                         = each.value.name
  location                     = var.location
  resource_group_name          = var.resource_group_name
  platform_fault_domain_count  = each.value.platform_fault_domain_count
  platform_update_domain_count = each.value.platform_update_domain_count
  managed                      = true

  tags = {
    Environment = var.environment
  }
}

# Network interfaces for VMs
resource "azurerm_network_interface" "vm_nic" {
  for_each = var.virtual_machines

  name                = "${each.value.name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = merge(
    {
      Environment = var.environment
    },
    try(each.value.tags, {})
  )
}

# Network Security Groups
resource "azurerm_network_security_group" "nsg" {
  for_each = var.network_security_groups

  name                = each.value.name
  location            = var.location
  resource_group_name = var.resource_group_name

  dynamic "security_rule" {
    for_each = each.value.rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range         = security_rule.value.source_port_range
      destination_port_range    = security_rule.value.destination_port_range
      source_address_prefix     = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }

  tags = {
    Environment = var.environment
  }
}

# Associate NSGs with NICs
resource "azurerm_network_interface_security_group_association" "nsg_association" {
  for_each = var.vm_nsg_associations

  network_interface_id      = azurerm_network_interface.vm_nic[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.value].id
}

# Create the Linux VMs
resource "azurerm_linux_virtual_machine" "vm" {
  for_each = var.virtual_machines

  name                = each.value.name
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = each.value.size
  admin_username      = var.admin_username
  network_interface_ids = [azurerm_network_interface.vm_nic[each.key].id]
  zone                = try(each.value.zones[0], null)
  availability_set_id = each.value.availability_set != null ? azurerm_availability_set.vm_avset[each.value.availability_set].id : null

  # SSH key authentication for Linux
  dynamic "admin_ssh_key" {
    for_each = var.ssh_public_key != null ? [1] : []
    content {
      username   = var.admin_username
      public_key = var.ssh_public_key
    }
  }

  os_disk {
    name                 = "${each.value.name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = each.value.os_disk_type
    disk_size_gb         = each.value.os_disk_size_gb
  }

  source_image_reference {
    publisher = each.value.publisher
    offer     = each.value.offer
    sku       = each.value.sku
    version   = each.value.version
  }

  identity {
    type = "SystemAssigned"
  }

  # Custom data for cloud-init if provided
  custom_data = try(base64encode(each.value.custom_data), null)

  # Linux-specific settings
  disable_password_authentication = var.ssh_public_key != null
  patch_mode                     = try(each.value.patch_mode, "ImageDefault")
  provision_vm_agent            = true

  tags = merge(
    {
      Environment = var.environment
    },
    try(each.value.tags, {})
  )

  lifecycle {
    ignore_changes = [
      tags["UpdatedDate"],
      tags["UpdatedBy"]
    ]
  }
}

# Create managed disks for data disks
resource "azurerm_managed_disk" "data_disk" {
  for_each = {
    for disk in flatten([
      for vm_key, vm in var.virtual_machines : [
        for disk_key, disk in try(vm.data_disks, {}) : {
          vm_key     = vm_key
          disk_key   = disk_key
          disk_name  = disk.name
          disk_size  = disk.size_gb
          disk_type  = disk.storage_account_type
        }
      ]
    ]) : "${disk.vm_key}-${disk.disk_key}" => disk
  }

  name                 = each.value.disk_name
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = each.value.disk_type
  create_option       = "Empty"
  disk_size_gb        = each.value.disk_size

  tags = {
    Environment = var.environment
  }
}

# Attach data disks to VMs
resource "azurerm_virtual_machine_data_disk_attachment" "disk_attachment" {
  for_each = {
    for disk in flatten([
      for vm_key, vm in var.virtual_machines : [
        for disk_key, disk in try(vm.data_disks, {}) : {
          vm_key     = vm_key
          disk_key   = disk_key
          disk_name  = disk.name
          lun        = disk.lun
        }
      ]
    ]) : "${disk.vm_key}-${disk.disk_key}" => disk
  }

  managed_disk_id    = azurerm_managed_disk.data_disk[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.vm[each.value.vm_key].id
  lun                = each.value.lun
  caching           = "ReadWrite"
}

# Backup policies for VMs that specify a backup policy
resource "azurerm_backup_protected_vm" "vm_backup" {
  for_each = {
    for k, v in var.virtual_machines : k => v
    if v.backup_policy_id != null
  }

  resource_group_name = var.resource_group_name
  recovery_vault_name = split("/", each.value.backup_policy_id)[8]
  source_vm_id        = azurerm_linux_virtual_machine.vm[each.key].id
  backup_policy_id    = each.value.backup_policy_id
}
