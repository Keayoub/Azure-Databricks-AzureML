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
  metastore_name   = "metastore-${var.project_name}"
  metastore_exists = contains(keys(data.databricks_metastores.available.ids), local.metastore_name)
  existing_id      = local.metastore_exists ? data.databricks_metastores.available.ids[local.metastore_name] : null
  
  metastore_container_name = "unity-catalog"
}

# ========== Create Metastore (if doesn't exist) ==========
resource "databricks_metastore" "primary" {
  provider      = databricks.accounts
  count         = local.metastore_exists ? 0 : 1
  name          = "metastore-${var.project_name}"
  region        = var.databricks_region
  force_destroy = var.environment_name != "prod"  # Safety: never force destroy in production

  storage_root = format("abfss://%s@%s.dfs.core.windows.net/",
    local.metastore_container_name,
    data.azurerm_storage_account.uc_metastore.name)
  
  lifecycle {
    prevent_destroy = false  # Set to true for production
    
    precondition {
      condition     = data.azurerm_storage_account.uc_metastore.account_tier == "Standard" || data.azurerm_storage_account.uc_metastore.account_tier == "Premium"
      error_message = "Metastore storage account must use Standard or Premium tier."
    }
    
    precondition {
      condition     = data.azurerm_storage_account.uc_metastore.is_hns_enabled == true
      error_message = "Metastore storage account must have hierarchical namespace (HNS) enabled for ADLS Gen2."
    }
  }
}

locals {
  metastore_id = local.metastore_exists ? local.existing_id : databricks_metastore.primary[0].id
  
  # Validation
  validate_metastore_id = local.metastore_id != null && local.metastore_id != "" ? local.metastore_id : null
}

# ========== Metastore Data Access Configuration ==========
resource "databricks_metastore_data_access" "uc_access" {
  provider     = databricks.accounts
  metastore_id  = local.validate_metastore_id
  name          = "uc-access-connector-${var.project_name}"
  force_destroy = var.environment_name != "prod"

  azure_managed_identity {
    access_connector_id = data.azurerm_databricks_access_connector.uc_connector.id
  }

  is_default = true
  
  lifecycle {
    ignore_changes = [
      is_default,  # May be changed manually
    ]
    
    precondition {
      condition     = local.validate_metastore_id != null
      error_message = "Metastore ID is required but not found. Ensure metastore creation succeeded."
    }
  }
}

# ========== Assign Metastore to Workspace ==========
resource "databricks_metastore_assignment" "workspace" {
  provider             = databricks.accounts
  metastore_id         = local.validate_metastore_id
  workspace_id         = var.databricks_workspace_id
  
  lifecycle {
    # Don't recreate if assignment already exists
    create_before_destroy = false
    
    precondition {
      condition     = can(regex("^[0-9]+$", tostring(var.databricks_workspace_id)))
      error_message = "Workspace ID must be a valid numeric ID."
    }
  }

  depends_on = [
    databricks_metastore_data_access.uc_access
  ]
}

# Set the default namespace (replacement for default_catalog_name)
resource "databricks_default_namespace_setting" "workspace" {
  namespace {
    value = "main"
  }
  
  lifecycle {
    # Ignore manual changes to namespace
    ignore_changes = [namespace]
  }

  depends_on = [
    databricks_metastore_assignment.workspace
  ]
}
