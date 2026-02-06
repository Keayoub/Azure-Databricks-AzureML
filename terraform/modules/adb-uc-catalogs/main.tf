# Azure Databricks Unity Catalog - Catalogs and Schemas Module

# ========== Query Existing Catalogs (for idempotency) ==========
data "databricks_catalogs" "existing" {}

locals {
  existing_catalog_names = toset([for c in data.databricks_catalogs.existing.catalogs : c.name])
  
  # Determine which catalogs to manage
  catalogs_to_manage = var.skip_existing_resources ? {
    for c in local.catalog_list : c.key => c
    if !contains(local.existing_catalog_names, c.name)
  } : { for c in local.catalog_list : c.key => c }
}

# ========== Create Catalogs ==========
resource "databricks_catalog" "this" {
  for_each     = local.catalogs_to_manage
  metastore_id = var.metastore_id
  name         = each.value.name
  comment      = each.value.comment
  force_destroy = var.environment_name != "prod"  # Safety: never force destroy in production
  
  lifecycle {
    # Prevent accidental deletion in production
    prevent_destroy = false  # Set to true for production environments
    
    # Ignore changes to these fields (managed outside Terraform)
    ignore_changes = [
      properties,  # Custom properties set via UI
    ]
    
    # Validate before creation
    precondition {
      condition     = can(regex("^[a-z0-9_]{3,255}$", each.value.name))
      error_message = "Catalog name '${each.value.name}' is invalid. Use 3-255 lowercase letters, numbers, and underscores."
    }
    
    precondition {
      condition     = var.metastore_id != null && var.metastore_id != ""
      error_message = "Metastore ID is required. Ensure metastore is created and assigned to workspace."
    }
  }
}

# Set catalog owner if specified
resource "databricks_grants" "catalog_owner" {
  for_each = {
    for c in local.catalog_list : c.key => c
    if c.owner != null && contains(keys(local.catalogs_to_manage), c.key)
  }
  catalog = databricks_catalog.this[each.key].name

  grant {
    principal  = each.value.owner
    privileges = ["OWNER"]
  }
  
  lifecycle {
    # Ignore manual permission changes
    ignore_changes = [grant]
  }
}

# ========== Create Schemas within Catalogs ==========
resource "databricks_schema" "this" {
  for_each = {
    for s in local.schema_list : "${s.catalog_key}.${s.schema_key}" => s
    if contains(keys(local.catalogs_to_manage), s.catalog_key)  # Only if catalog is managed
  }
  catalog_name  = databricks_catalog.this[each.value.catalog_key].name
  name          = each.value.name
  comment       = each.value.comment
  force_destroy = var.environment_name != "prod"
  
  lifecycle {
    prevent_destroy = false  # Set to true for production
    
    ignore_changes = [
      properties,
    ]
    
    precondition {
      condition     = can(regex("^[a-z0-9_]{1,255}$", each.value.name))
      error_message = "Schema name '${each.value.name}' is invalid. Use lowercase letters, numbers, and underscores."
    }
  }
}

# Set schema owner if specified
resource "databricks_grants" "schema_owner" {
  for_each = {
    for s in local.schema_list : "${s.catalog_key}.${s.schema_key}" => s
    if s.owner != null && contains(keys(local.catalogs_to_manage), s.catalog_key)
  }
  catalog = databricks_catalog.this[each.value.catalog_key].name
  schema  = databricks_schema.this["${each.value.catalog_key}.${each.value.schema_key}"].name

  grant {
    principal  = each.value.owner
    privileges = ["OWNER"]
  }
  
  lifecycle {
    ignore_changes = [grant]
  }
}
