# ========================================
# Unity Catalog Metastore Layer
# ========================================
# Purpose: Create/reference metastore (one-time per region)
# Runs during: azd provision (postprovision hook)

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.52"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Workspace-based authentication (Azure Databricks pattern)
provider "databricks" {
  host = var.databricks_workspace_host
}

# Account-level authentication (required for metastores)
provider "databricks" {
  alias      = "accounts"
  host       = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_account_id
}

# ========== Reference Azure Resources ==========
data "azurerm_storage_account" "uc_metastore" {
  name                = var.metastore_storage_name
  resource_group_name = var.shared_resource_group_name
}

data "azurerm_databricks_access_connector" "uc_connector" {
  name                = var.access_connector_name
  resource_group_name = var.shared_resource_group_name
}

# ========== Check for Existing Metastore ==========
data "databricks_metastores" "available" {
  provider = databricks.accounts
}

locals {
  metastore_exists = length(data.databricks_metastores.available.ids) > 0
  metastore_name   = "metastore-${var.environment_name}"
  existing_id      = local.metastore_exists ? try(data.databricks_metastores.available.ids[local.metastore_name], values(data.databricks_metastores.available.ids)[0]) : null
  
  metastore_container_name = "unity-catalog"
}

# ========== Create Metastore (if doesn't exist) ==========
resource "databricks_metastore" "primary" {
  provider      = databricks.accounts
  count         = local.metastore_exists ? 0 : 1
  name          = "metastore-${var.environment_name}"
  force_destroy = true

  storage_root = format("abfss://%s@%s.dfs.core.windows.net/",
    local.metastore_container_name,
    data.azurerm_storage_account.uc_metastore.name)
}

locals {
  metastore_id = local.metastore_exists ? local.existing_id : databricks_metastore.primary[0].id
}

# ========== Metastore Data Access Configuration ==========
resource "databricks_metastore_data_access" "uc_access" {
  provider     = databricks.accounts
  metastore_id  = local.metastore_id
  name          = "uc-access-connector-${var.environment_name}"
  force_destroy = true

  azure_managed_identity {
    access_connector_id = data.azurerm_databricks_access_connector.uc_connector.id
  }

  is_default = true
  
  lifecycle {
    ignore_changes = [is_default]
  }
}

# ========== Assign Metastore to Workspace ==========
resource "databricks_metastore_assignment" "workspace" {
  provider             = databricks.accounts
  metastore_id         = local.metastore_id
  workspace_id         = var.databricks_workspace_id
  default_catalog_name = "main"

  depends_on = [
    databricks_metastore_data_access.uc_access
  ]
}
