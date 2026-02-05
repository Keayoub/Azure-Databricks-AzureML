output "metastore_id" {
  description = "Unity Catalog metastore ID"
  value       = module.uc_metastore.metastore_id
}

output "metastore_name" {
  description = "Unity Catalog metastore name"
  value       = module.uc_metastore.metastore_name
}

output "catalogs" {
  description = "Created catalogs"
  value       = module.uc_catalogs.catalogs
}

output "schemas" {
  description = "Created schemas"
  value       = module.uc_catalogs.schemas
}

output "volumes" {
  description = "Created volumes"
  value       = module.uc_volumes.volumes
}

output "storage_account_id" {
  description = "UC metastore storage account ID"
  value       = module.uc_metastore.storage_account_id
}

output "access_connector_id" {
  description = "UC access connector ID"
  value       = module.uc_metastore.access_connector_id
}
