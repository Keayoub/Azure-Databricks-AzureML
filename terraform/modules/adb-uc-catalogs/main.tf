# Azure Databricks Unity Catalog - Catalogs and Schemas Module

# ========== Create Catalogs ==========
resource "databricks_catalog" "this" {
  for_each     = { for c in local.catalog_list : c.key => c }
  metastore_id = var.metastore_id
  name         = each.value.name
  comment      = each.value.comment
  force_destroy = true
}

# Set catalog owner if specified
resource "databricks_grants" "catalog_owner" {
  for_each = {
    for c in local.catalog_list : c.key => c
    if c.owner != null
  }
  catalog = databricks_catalog.this[each.key].name

  grant {
    principal  = each.value.owner
    privileges = ["OWNER"]
  }
}

# ========== Create Schemas within Catalogs ==========
resource "databricks_schema" "this" {
  for_each = {
    for s in local.schema_list : "${s.catalog_key}.${s.schema_key}" => s
  }
  catalog_name  = databricks_catalog.this[each.value.catalog_key].name
  name          = each.value.name
  comment       = each.value.comment
  force_destroy = true
}

# Set schema owner if specified
resource "databricks_grants" "schema_owner" {
  for_each = {
    for s in local.schema_list : "${s.catalog_key}.${s.schema_key}" => s
    if s.owner != null
  }
  catalog = databricks_catalog.this[each.value.catalog_key].name
  schema  = databricks_schema.this["${each.value.catalog_key}.${each.value.schema_key}"].name

  grant {
    principal  = each.value.owner
    privileges = ["OWNER"]
  }
}
