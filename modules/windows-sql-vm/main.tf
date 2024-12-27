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

# Create public IPs if requested
resource "azurerm_public_ip" "vm_pip" {
  for_each = {
    for ip in flatten([
      for vm_key, vm in var.virtual_machines : [
        for ip_key, ip in vm.ip_configurations : {
          vm_key = vm_key
          ip_key = ip_key
          config = ip
          vm_name = vm.name
        } if ip.create_public_ip == true
      ]
    ]) : "${ip.vm_key}-${ip.ip_key}" => ip
  }

  name                = "pip-${each.value.vm_name}-${each.value.ip_key}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = each.value.config.public_ip_allocation
  sku                = each.value.config.public_ip_sku
  zones              = try(var.virtual_machines[each.value.vm_key].zones, null)

  tags = try(var.virtual_machines[each.value.vm_key].tags, {})
}

# Network interfaces for VMs
resource "azurerm_network_interface" "vm_nic" {
  for_each = var.virtual_machines

  name                = "${each.value.name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  dynamic "ip_configuration" {
    for_each = each.value.ip_configurations
    content {
      name                          = ip_configuration.value.name
      subnet_id                     = ip_configuration.value.subnet_id
      private_ip_address_allocation = ip_configuration.value.private_ip_address_allocation
      private_ip_address           = ip_configuration.value.private_ip_address
      primary                      = ip_configuration.value.primary
      public_ip_address_id         = ip_configuration.value.create_public_ip ? azurerm_public_ip.vm_pip["${each.key}-${ip_configuration.key}"].id : null
    }
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
resource "azurerm_network_interface_security_group_association" "vm_nsg_association" {
  for_each = var.vm_nsg_associations

  network_interface_id      = azurerm_network_interface.vm_nic[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.value].id
}

# Data disks
resource "azurerm_managed_disk" "data_disk" {
  for_each = {
    for disk in flatten([
      for vm_key, vm in var.virtual_machines : [
        for disk_key, disk in try(vm.data_disks, {}) : {
          vm_key     = vm_key
          disk_key   = disk_key
          disk      = disk
          vm_name   = vm.name
        }
      ]
    ]) : "${disk.vm_key}-${disk.disk_key}" => disk
  }

  name                 = "disk-${each.value.vm_name}-${each.value.disk_key}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = each.value.disk.managed_disk_type
  create_option       = each.value.disk.create_option
  disk_size_gb       = each.value.disk.disk_size_gb

  tags = try(var.virtual_machines[each.value.vm_key].tags, {})
}

# Virtual Machines
resource "azurerm_windows_virtual_machine" "vm" {
  for_each = var.virtual_machines

  name                = each.value.name
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = each.value.size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  timezone           = each.value.timezone
  network_interface_ids = [
    azurerm_network_interface.vm_nic[each.key].id
  ]
  patch_mode         = each.value.patch_mode
  availability_set_id = try(azurerm_availability_set.vm_avset[each.value.availability_set].id, null)

  os_disk {
    name                 = "${each.value.name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = each.value.os_disk_type
    disk_size_gb        = each.value.os_disk_size_gb
  }

  source_image_reference {
    publisher = "MicrosoftSQLServer"
    offer     = "SQL2019-WS2019"
    sku       = "Standard"
    version   = "latest"
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

# Attach data disks to VMs
resource "azurerm_virtual_machine_data_disk_attachment" "vm_data_disk" {
  for_each = {
    for disk in flatten([
      for vm_key, vm in var.virtual_machines : [
        for disk_key, disk in try(vm.data_disks, {}) : {
          vm_key     = vm_key
          disk_key   = disk_key
          disk      = disk
        }
      ]
    ]) : "${disk.vm_key}-${disk.disk_key}" => disk
  }

  managed_disk_id    = azurerm_managed_disk.data_disk[each.key].id
  virtual_machine_id = azurerm_windows_virtual_machine.vm[each.value.vm_key].id
  lun               = each.value.disk.lun
  caching           = each.value.disk.caching
}

# SQL Server configuration
resource "azurerm_mssql_virtual_machine" "sql_vm" {
  for_each = var.virtual_machines

  virtual_machine_id               = azurerm_windows_virtual_machine.vm[each.key].id
  sql_license_type                = "PAYG"
  r_services_enabled              = false
  sql_connectivity_port           = each.value.sql_configuration.sql_connectivity_port
  sql_connectivity_type           = each.value.sql_configuration.sql_connectivity_type

  sql_connectivity_update_username = var.admin_username
  sql_connectivity_update_password = var.admin_password

  auto_patching {
    day_of_week                            = "Sunday"
    maintenance_window_duration_in_minutes = 60
    maintenance_window_starting_hour       = 2
  }

  storage_configuration {
    disk_type             = each.value.sql_configuration.storage_configuration.disk_type
    storage_workload_type = each.value.sql_configuration.storage_configuration.storage_workload_type

    data_settings {
      default_file_path = each.value.sql_configuration.storage_configuration.data_settings.default_file_path
      luns             = each.value.sql_configuration.storage_configuration.data_settings.luns
    }

    log_settings {
      default_file_path = each.value.sql_configuration.storage_configuration.log_settings.default_file_path
      luns             = each.value.sql_configuration.storage_configuration.log_settings.luns
    }

    temp_db_settings {
      default_file_path = each.value.sql_configuration.storage_configuration.temp_db_settings.default_file_path
      luns             = each.value.sql_configuration.storage_configuration.temp_db_settings.luns
    }
  }
}
