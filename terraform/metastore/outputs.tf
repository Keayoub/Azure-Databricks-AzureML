# ========================================
# Metastore Module Outputs
# ========================================

output "metastore_id" {
  description = "Unity Catalog metastore ID"
  value       = local.metastore_id
}

output "metastore_exists" {
  description = "Whether metastore already existed"
  value       = local.metastore_exists
}

output "metastore_assignment_id" {
  description = "Metastore assignment ID"
  value       = databricks_metastore_assignment.workspace.id
}
