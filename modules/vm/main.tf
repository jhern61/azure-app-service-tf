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

# Create the VMs
resource "azurerm_virtual_machine" "vm" {
  for_each = var.virtual_machines

  name                  = each.value.name
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.vm_nic[each.key].id]
  vm_size              = each.value.size
  zones                = each.value.zones
  availability_set_id  = each.value.availability_set != null ? azurerm_availability_set.vm_avset[each.value.availability_set].id : null

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = each.value.publisher
    offer     = each.value.offer
    sku       = each.value.sku
    version   = each.value.version
  }

  storage_os_disk {
    name              = "${each.value.name}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = each.value.os_disk_type
    disk_size_gb      = each.value.os_disk_size_gb
  }

  dynamic "storage_data_disk" {
    for_each = try(each.value.data_disks, {})
    content {
      name              = storage_data_disk.value.name
      create_option     = storage_data_disk.value.create_option
      disk_size_gb      = storage_data_disk.value.size_gb
      lun               = storage_data_disk.value.lun
      managed_disk_type = storage_data_disk.value.storage_account_type
    }
  }

  os_profile {
    computer_name  = each.value.name
    admin_username = var.admin_username
    admin_password = var.admin_password
    custom_data    = each.value.custom_data
  }

  os_profile_windows_config {
    provision_vm_agent        = true
    enable_automatic_upgrades = true
  }

  identity {
    type = "SystemAssigned"
  }

  tags = merge(
    {
      Environment = var.environment
    },
    try(each.value.tags, {})
  )
}

# Random string for unique storage account name
resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}

# Storage account for SQL backups
resource "azurerm_storage_account" "sql_backup" {
  name                     = "sqlbackup${var.environment}${random_string.unique.result}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    Environment = var.environment
  }
}

# SQL Server configuration for VMs that require it
resource "azurerm_mssql_virtual_machine" "sql_vm" {
  for_each = {
    for k, v in var.virtual_machines : k => v
    if try(v.is_sql_server, false)
  }

  virtual_machine_id               = azurerm_virtual_machine.vm[each.key].id
  sql_license_type                = each.value.sql_connectivity.sql_license_type
  r_services_enabled              = true
  sql_connectivity_port           = each.value.sql_connectivity.sql_port
  sql_connectivity_type           = each.value.sql_connectivity.sql_connectivity_type
  sql_connectivity_update_password = var.admin_password
  sql_connectivity_update_username = var.admin_username

  auto_patching {
    day_of_week                            = "Sunday"
    maintenance_window_duration_in_minutes = 60
    maintenance_window_starting_hour       = 2
  }

  auto_backup {
    retention_period_in_days    = 30
    storage_account_access_key  = azurerm_storage_account.sql_backup.primary_access_key
    storage_blob_endpoint       = azurerm_storage_account.sql_backup.primary_blob_endpoint
  }
}

# Key Vault access policy for VMs
resource "azurerm_key_vault_access_policy" "vm_policy" {
  for_each = var.virtual_machines

  key_vault_id = var.key_vault_id
  tenant_id    = azurerm_virtual_machine.vm[each.key].identity[0].tenant_id
  object_id    = azurerm_virtual_machine.vm[each.key].identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# Backup policies for VMs that specify a backup policy
resource "azurerm_backup_protected_vm" "vm_backup" {
  for_each = {
    for k, v in var.virtual_machines : k => v
    if v.backup_policy_id != null
  }

  resource_group_name = var.resource_group_name
  recovery_vault_name = split("/", each.value.backup_policy_id)[8]
  source_vm_id        = azurerm_virtual_machine.vm[each.key].id
  backup_policy_id    = each.value.backup_policy_id
}
