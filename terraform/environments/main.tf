# ========================================
# Unity Catalog Components Layer
# ========================================
# Purpose: Deploy catalogs, schemas, and volumes
# Runs during: azd deploy (postdeploy hook)
# Prerequisites: Metastore must exist (created via azd provision)

# ========== Get Workspace Metastore Assignment ==========
# Query the metastore assigned to this workspace
data "databricks_current_metastore" "this" {}

locals {
  metastore_id = data.databricks_current_metastore.this.id
  
  # Deployment flags
  deploy_catalogs = var.enable_catalog_management && length(var.catalogs) > 0
  deploy_volumes  = var.enable_volume_management && length(var.volumes) > 0
}

# ========== UC Catalogs and Schemas Module ==========
module "uc_catalogs" {
  count  = local.deploy_catalogs ? 1 : 0
  source = "../modules/adb-uc-catalogs"

  metastore_id            = local.metastore_id
  catalogs                = var.catalogs
  tags                    = var.tags
  skip_existing_resources = var.skip_existing_resources
  environment_name        = var.environment_name
}

# ========== UC Volumes Module ==========
module "uc_volumes" {
  count  = local.deploy_volumes ? 1 : 0
  source = "../modules/adb-uc-volumes"

  volumes                 = var.volumes
  tags                    = var.tags
  skip_existing_resources = var.skip_existing_resources
  environment_name        = var.environment_name

  depends_on = [
    module.uc_catalogs
  ]
}

