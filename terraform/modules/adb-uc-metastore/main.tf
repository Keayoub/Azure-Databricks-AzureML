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

# ========== Check for existing metastore via Databricks CLI ==========
data "external" "existing_metastore" {
  program = ["bash", "-c", <<-EOT
    # Check if metastore exists in this account
    METASTORE_ID=$(databricks metastores list --output json 2>/dev/null | jq -r '.[0].metastore_id // ""')
    
    if [ -n "$METASTORE_ID" ]; then
      echo "{\"metastore_id\":\"$METASTORE_ID\",\"exists\":\"true\"}"
    else
      echo "{\"metastore_id\":\"\",\"exists\":\"false\"}"
    fi
  EOT
  ]
}

locals {
  metastore_exists = data.external.existing_metastore.result.exists == "true"
  existing_id      = data.external.existing_metastore.result.metastore_id
}

# ========== Create Metastore (only if doesn't exist) ==========
resource "databricks_metastore" "primary" {
  count         = local.metastore_exists ? 0 : 1
  name          = "metastore-${var.environment_name}"
  owner         = var.metastore_owner
  force_destroy = true

  storage_root = format("abfss://%s@%s.dfs.core.windows.net/",
    local.metastore_container_name,
    data.azurerm_storage_account.uc_metastore.name)
}

# ========== Import existing metastore if found ==========
import {
  to = databricks_metastore.primary[0]
  id = local.existing_id
  
  # Only import if metastore exists
  for_each = local.metastore_exists ? toset([local.existing_id]) : toset([])
}

locals {
  metastore_id = local.metastore_exists ? local.existing_id : databricks_metastore.primary[0].id
}

# ========== Metastore Data Access (Credentials) ==========
resource "databricks_metastore_data_access" "uc_access" {
  count         = local.metastore_exists ? 0 : 1  # Only for new metastores
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
  workspace_id = var.databricks_workspace_id
}

# ========== Default Namespace Setting ==========
resource "databricks_default_namespace_setting" "this" {
  namespace {
    value = "main"
  }

  depends_on = [databricks_metastore_assignment.workspace]
}
