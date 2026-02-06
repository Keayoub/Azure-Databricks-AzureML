# ========================================
# Unity Catalog Components Outputs
# ========================================
# Note: Metastore outputs are in terraform/metastore/outputs.tf

output "metastore_id" {
  description = "Unity Catalog metastore ID (referenced from existing)"
  value       = local.metastore_id
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
