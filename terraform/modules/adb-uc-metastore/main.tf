# Azure Databricks Unity Catalog Metastore Module
# Creates UC-specific storage, access connector, and metastore configuration

# ========== Storage Account for UC Metastore ==========
resource "azurerm_storage_account" "uc_metastore" {
  name                     = local.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.storage_account_replication_type
  is_hns_enabled           = true # Required for ADLS Gen2
  shared_access_key_enabled = true

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  tags = var.tags
}

# Storage container for UC metastore root
resource "azurerm_storage_container" "uc_metastore" {
  name                  = local.metastore_container_name
  storage_account_name  = azurerm_storage_account.uc_metastore.name
  container_access_type = "private"
}

# ========== Databricks Access Connector (Managed Identity) ==========
resource "azurerm_databricks_access_connector" "uc_connector" {
  name                = local.access_connector_name
  resource_group_name = var.resource_group_name
  location            = var.location
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Grant access connector identity to UC storage account
resource "azurerm_role_assignment" "uc_storage_access" {
  for_each             = toset(["Storage Blob Data Contributor", "Storage Queue Data Contributor"])
  scope                = azurerm_storage_account.uc_metastore.id
  role_definition_name = each.value
  principal_id         = azurerm_databricks_access_connector.uc_connector.identity[0].principal_id
}

# ========== Databricks UC Metastore ==========
resource "databricks_metastore" "primary" {
  provider      = databricks
  name          = "primary"
  owner         = var.metastore_owner
  force_destroy = true

  storage_root = format("abfss://%s@%s.dfs.core.windows.net/",
    azurerm_storage_container.uc_metastore.name,
  azurerm_storage_account.uc_metastore.name)

  depends_on = [
    azurerm_role_assignment.uc_storage_access,
    azurerm_storage_container.uc_metastore,
  ]
}

# ========== Metastore Data Access (Credentials) ==========
resource "databricks_metastore_data_access" "uc_access" {
  provider     = databricks
  metastore_id = databricks_metastore.primary.id
  name         = "uc-access-connector"
  force_destroy = true

  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.uc_connector.id
  }

  is_default = true
}

# ========== Assign Metastore to Workspace ==========
resource "databricks_metastore_assignment" "workspace" {
  provider             = databricks
  metastore_id         = databricks_metastore.primary.id
  workspace_id         = var.databricks_workspace_id
  default_catalog_name = "main"
}

# ========== Default Namespace Setting ==========
resource "databricks_default_namespace_setting" "this" {
  provider = databricks
  namespace {
    value = "main"
  }

  depends_on = [databricks_metastore_assignment.workspace]
}
