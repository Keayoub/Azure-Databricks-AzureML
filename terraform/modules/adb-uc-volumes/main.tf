# Azure Databricks Unity Catalog - Volumes Module

# ========== Create Volumes within Schemas ==========
resource "databricks_volume" "this" {
  for_each     = var.volumes
  catalog_name = each.value.catalog_name
  schema_name  = each.value.schema_name
  name         = each.value.name
  comment      = each.value.comment
  volume_type  = "EXTERNAL" # EXTERNAL for mounted storage, MANAGED for Databricks-managed
}

# Set volume owner if specified
resource "databricks_grants" "volume_owner" {
  for_each = {
    for key, vol in var.volumes : key => vol
    if vol.owner != null
  }
  catalog = each.value.catalog_name
  schema  = each.value.schema_name
  volume  = databricks_volume.this[each.key].name

  grant {
    principal  = each.value.owner
    privileges = ["OWNER"]
  }
}
