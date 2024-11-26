# Azure SQL Elastic Pool Terraform Module

This module creates an Azure SQL Elastic Pool for managing and sharing resources between multiple Azure SQL Databases.

## Features

- Creates an Azure SQL Elastic Pool with configurable settings
- Supports all SKU tiers (Basic, Standard, Premium)
- Configurable per-database settings
- Prevents accidental deletion with lifecycle rules
- Comprehensive input validation
- Standardized tagging system

## Usage

```hcl
module "elastic_pool" {
  source = "./modules/elastic-pool"

  elastic_pool_name        = "my-elastic-pool"
  resource_group_name      = "my-resource-group"
  location                = "eastus2"
  server_name             = "my-sql-server"
  max_size_gb             = 50

  sku_name                = "StandardPool"
  sku_tier                = "Standard"
  sku_family              = "Gen5"
  sku_capacity            = 2

  per_database_min_capacity = 0.25
  per_database_max_capacity = 4

  environment             = "production"
  
  tags = {
    Owner       = "DevOps"
    CostCenter  = "IT-123"
  }
}
```

## Requirements

- Azure Provider >= 2.0
- Terraform >= 0.13

## Input Variables

| Name | Description | Type | Required |
|------|-------------|------|----------|
| elastic_pool_name | Name of the elastic pool | string | yes |
| resource_group_name | Name of the resource group | string | yes |
| location | Azure region location | string | yes |
| server_name | Name of the SQL server | string | yes |
| max_size_gb | The max size of the elastic pool in GB | number | yes |
| sku_name | The name of the SKU | string | yes |
| sku_tier | The tier of the SKU | string | yes |
| sku_family | The family of hardware | string | yes |
| sku_capacity | The scale up/out capacity | number | yes |
| per_database_min_capacity | Minimum capacity per database | number | yes |
| per_database_max_capacity | Maximum capacity per database | number | yes |
| environment | Environment name for tagging | string | yes |
| tags | Additional tags (optional) | map(string) | no |

## Outputs

| Name | Description |
|------|-------------|
| elastic_pool_id | The ID of the elastic pool |
| elastic_pool_name | The name of the elastic pool |

## Notes

- The module implements prevent_destroy to avoid accidental deletion
- Tags are merged with default tags that include Environment, ManagedBy, and Module
- SKU tier must be one of: Basic, Standard, or Premium
- SKU family must be either Gen4 or Gen5
- Elastic pool name must be between 3 and 63 characters long
