output "metastore_id" {
  description = "ID of the created UC metastore"
  value       = databricks_metastore.primary.id
}

output "metastore_name" {
  description = "Name of the created UC metastore"
  value       = databricks_metastore.primary.name
}

output "storage_account_id" {
  description = "ID of the storage account used by UC metastore"
  value       = data.azurerm_storage_account.uc_metastore.id
}

output "storage_account_name" {
  description = "Name of the storage account used by UC metastore"
  value       = data.azurerm_storage_account.uc_metastore.name
}

output "access_connector_id" {
  description = "ID of the Databricks access connector"
  value       = data.azurerm_databricks_access_connector.uc_connector.id
}

output "access_connector_principal_id" {
  description = "Principal ID of the managed identity for access connector"
  value       = data.azurerm_databricks_access_connector.uc_connector.identity[0].principal_id
}
