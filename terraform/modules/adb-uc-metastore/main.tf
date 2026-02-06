# Azure Databricks Unity Catalog Metastore Module
# References existing Azure infrastructure created by Bicep and configures Unity Catalog

# ========== Reference Existing Storage Account ==========
data "azurerm_storage_account" "uc_metastore" {
  name                = var.metastore_storage_name
  resource_group_name = var.resource_group_name
}

# Note: We don't read the storage container data source because the storage account
# has key-based authentication disabled for security. We use the known container name
# from Bicep: local.metastore_container_name

# ========== Databricks Access Connector ==========
data "azurerm_databricks_access_connector" "uc_connector" {
  name                = var.access_connector_name
  resource_group_name = var.resource_group_name
}

# ========== Auto-detect Existing Metastores ==========
# Get all metastores - if one exists in this region, we'll use it
data "databricks_metastores" "all" {}

locals {
  # Check if any metastore exists
  existing_metastores    = data.databricks_metastores.all.ids
  has_existing_metastore = length(local.existing_metastores) > 0
  existing_metastore_id  = local.has_existing_metastore ? local.existing_metastores[0] : null
}

# ========== Create New Metastore (only if none exists) ==========
resource "databricks_metastore" "primary" {
  count         = local.has_existing_metastore ? 0 : 1
  name          = "metastore-${var.environment_name}"
  owner         = var.metastore_owner
  force_destroy = true

  storage_root = format("abfss://%s@%s.dfs.core.windows.net/",
    local.metastore_container_name,
    data.azurerm_storage_account.uc_metastore.name)
}

# ========== Unified Metastore ID ==========
locals {
  metastore_id = local.has_existing_metastore ? local.existing_metastore_id : databricks_metastore.primary[0].id
}

# ========== Metastore Data Access (Credentials) ==========
# Only create for new metastores (existing ones already have credentials)
resource "databricks_metastore_data_access" "uc_access" {
  count         = local.has_existing_metastore ? 0 : 1
  metastore_id  = local.metastore_id
  name          = "uc-access-connector"
  force_destroy = true

  azure_managed_identity {
    access_connector_id = data.azurerm_databricks_access_connector.uc_connector.id
  }

  is_default = true
}

# ========== Assign Metastore to Workspace ==========
resource "databricks_metastore_assignment" "workspace" {
  metastore_id = local.metastore_id
  workspace_id         = var.databricks_workspace_id
}

# ========== Default Namespace Setting ==========
resource "databricks_default_namespace_setting" "this" {
  namespace {
    value = "main"
  }

  depends_on = [databricks_metastore_assignment.workspace]
}
