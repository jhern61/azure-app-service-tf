output "sql_server_id" {
  description = "The ID of the SQL Server"
  value       = azurerm_mssql_server.sql_server.id
}

output "sql_server_name" {
  description = "The name of the SQL Server"
  value       = azurerm_mssql_server.sql_server.name
}

output "sql_server_fqdn" {
  description = "The fully qualified domain name of the SQL Server"
  value       = azurerm_mssql_server.sql_server.fully_qualified_domain_name
}

output "database_ids" {
  description = "Map of database names to their IDs"
  value       = { for k, v in azurerm_mssql_database.databases : k => v.id }
}

output "database_names" {
  description = "Map of database names"
  value       = { for k, v in azurerm_mssql_database.databases : k => v.name }
}
