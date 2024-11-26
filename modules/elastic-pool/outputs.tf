output "elastic_pool_id" {
  description = "The ID of the elastic pool"
  value       = azurerm_mssql_elasticpool.elastic_pool.id
}

output "elastic_pool_name" {
  description = "The name of the elastic pool"
  value       = azurerm_mssql_elasticpool.elastic_pool.name
}
