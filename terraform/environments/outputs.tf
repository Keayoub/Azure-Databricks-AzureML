# ========================================
# Unity Catalog Components Outputs (Enhanced)
# ========================================
# Note: Metastore outputs are in terraform/metastore/outputs.tf

output "metastore_id" {
  description = "Unity Catalog metastore ID (referenced from existing)"
  value       = local.metastore_id
  sensitive   = false  # IDs are safe to show
}

output "catalogs" {
  description = "Created catalogs"
  value       = local.deploy_catalogs ? try(module.uc_catalogs[0].catalogs, {}) : {}
  sensitive   = false
}

output "schemas" {
  description = "Created schemas"
  value       = local.deploy_catalogs ? try(module.uc_catalogs[0].schemas, {}) : {}
  sensitive   = false
}

output "volumes" {
  description = "Created volumes"
  value       = local.deploy_volumes ? try(module.uc_volumes[0].volumes, {}) : {}
  sensitive   = false
}

output "deployment_summary" {
  description = "Summary of deployment configuration"
  value = {
    environment             = var.environment_name
    catalogs_enabled        = var.enable_catalog_management
    catalogs_deployed       = local.deploy_catalogs
    catalog_count           = local.deploy_catalogs ? length(try(module.uc_catalogs[0].catalogs, {})) : 0
    volumes_enabled         = var.enable_volume_management
    volumes_deployed        = local.deploy_volumes
    volume_count            = local.deploy_volumes ? length(try(module.uc_volumes[0].volumes, {})) : 0
    skip_existing_resources = var.skip_existing_resources
  }
  sensitive = false
}
