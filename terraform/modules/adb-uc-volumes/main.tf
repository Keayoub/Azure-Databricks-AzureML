# Azure Databricks Unity Catalog - Volumes Module

# ========== Create Volumes within Schemas ==========
resource "databricks_volume" "this" {
  for_each     = var.volumes
  catalog_name = each.value.catalog_name
  schema_name  = each.value.schema_name
  name         = each.value.name
  comment      = each.value.comment
  volume_type  = "EXTERNAL" # EXTERNAL for mounted storage, MANAGED for Databricks-managed
  
  lifecycle {
    # Prevent accidental deletion (volumes contain data)
    prevent_destroy = false  # Set to true for production
    
    # Ignore manual changes
    ignore_changes = [
      storage_location,  # May be set via external location
    ]
    
    # Validation
    precondition {
      condition     = can(regex("^[a-z0-9_]{1,255}$", each.value.name))
      error_message = "Volume name '${each.value.name}' is invalid. Use lowercase letters, numbers, and underscores."
    }
    
    precondition {
      condition     = each.value.catalog_name != null && each.value.catalog_name != ""
      error_message = "Volume '${each.value.name}' requires a valid catalog_name."
    }
    
    precondition {
      condition     = each.value.schema_name != null && each.value.schema_name != ""
      error_message = "Volume '${each.value.name}' requires a valid schema_name."
    }
  }
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
  
  lifecycle {
    ignore_changes = [grant]
  }
}
