locals {
  name_prefix           = "${var.project_name}-${var.environment_name}"
  uc_access_connector_name = "ac-${local.name_prefix}-uc"
}

import {
  to = module.uc_metastore.azurerm_databricks_access_connector.uc_connector
  id = format(
    "/subscriptions/%s/resourceGroups/%s/providers/Microsoft.Databricks/accessConnectors/%s",
    var.subscription_id,
    var.shared_resource_group_name,
    local.uc_access_connector_name
  )
}

# ========== UC Metastore Module ==========
module "uc_metastore" {
  source = "../modules/adb-uc-metastore"

  providers = {
    azurerm    = azurerm
    databricks = databricks.account
  }

  subscription_id           = var.subscription_id
  resource_group_name       = var.shared_resource_group_name
  location                  = var.azure_region
  environment_name          = var.environment_name
  project_name              = var.project_name
  databricks_workspace_id   = var.databricks_workspace_id
  databricks_workspace_host = var.databricks_workspace_host
  databricks_account_id     = var.databricks_account_id
  metastore_owner           = var.metastore_owner
  storage_account_replication_type = var.storage_account_replication_type
  tags                      = var.tags
}

# ========== UC Catalogs and Schemas Module ==========
module "uc_catalogs" {
  source = "../modules/adb-uc-catalogs"

  providers = {
    databricks = databricks.workspace
  }

  metastore_id = module.uc_metastore.metastore_id
  catalogs     = var.catalogs
  tags         = var.tags

  depends_on = [
    module.uc_metastore
  ]
}

# ========== UC Volumes Module ==========
module "uc_volumes" {
  source = "../modules/adb-uc-volumes"

  providers = {
    databricks = databricks.workspace
  }

  volumes = var.volumes
  tags    = var.tags

  depends_on = [
    module.uc_catalogs
  ]
}

