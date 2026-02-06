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

# ========== Reference Existing Databricks Access Connector ==========
data "azurerm_databricks_access_connector" "uc_connector" {
  name                = var.access_connector_name
  resource_group_name = var.resource_group_name
}

# ========== Databricks UC Metastore ==========
resource "databricks_metastore" "primary" {
  name          = "primary"
  owner         = var.metastore_owner
  force_destroy = true

  storage_root = format("abfss://%s@%s.dfs.core.windows.net/",
    local.metastore_container_name,
  data.azurerm_storage_account.uc_metastore.name)
}

# ========== Metastore Data Access (Credentials) ==========
resource "databricks_metastore_data_access" "uc_access" {
  metastore_id = databricks_metastore.primary.id
  name         = "uc-access-connector"
  force_destroy = true

  azure_managed_identity {
    access_connector_id = data.azurerm_databricks_access_connector.uc_connector.id
  }

  is_default = true
}

# ========== Assign Metastore to Workspace ==========
resource "databricks_metastore_assignment" "workspace" {
  metastore_id         = databricks_metastore.primary.id
  workspace_id         = var.databricks_workspace_id
}

# ========== Default Namespace Setting ==========
resource "databricks_default_namespace_setting" "this" {
  namespace {
    value = "main"
  }

  depends_on = [databricks_metastore_assignment.workspace]
}
