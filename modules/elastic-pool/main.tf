locals {
  default_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Module      = "elastic-pool"
  }
  merged_tags = merge(local.default_tags, var.tags)
}

resource "azurerm_mssql_elasticpool" "elastic_pool" {
  name                = var.elastic_pool_name
  resource_group_name = var.resource_group_name
  location            = var.location
  server_name         = var.server_name
  max_size_gb         = var.max_size_gb

  # License Type can be added if needed
  # license_type = "LicenseIncluded"

  sku {
    name     = var.sku_name
    tier     = var.sku_tier
    family   = var.sku_family
    capacity = var.sku_capacity
  }

  per_database_settings {
    min_capacity = var.per_database_min_capacity
    max_capacity = var.per_database_max_capacity
  }

  lifecycle {
    # Prevent accidental deletion of the elastic pool
    prevent_destroy = true

    # Ignore changes to tags, as they might be updated outside of Terraform
    ignore_changes = [
      tags["UpdatedDate"],
      tags["UpdatedBy"]
    ]
  }

  tags = local.merged_tags
}
