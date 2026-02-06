# ========================================
# Unity Catalog Components Layer
# ========================================
# Purpose: Deploy catalogs, schemas, and volumes
# Runs during: azd deploy (postdeploy hook)
# Prerequisites: Metastore must exist (created via azd provision)

# ========== Get Existing Metastore ==========
data "databricks_metastores" "available" {}

locals {
  metastore_id = data.databricks_metastores.available.ids[0]
}

# ========== UC Catalogs and Schemas Module ==========
module "uc_catalogs" {
  source = "../modules/adb-uc-catalogs"

  metastore_id = local.metastore_id
  catalogs     = var.catalogs
  tags         = var.tags
}

# ========== UC Volumes Module ==========
module "uc_volumes" {
  source = "../modules/adb-uc-volumes"

  volumes = var.volumes
  tags    = var.tags

  depends_on = [
    module.uc_catalogs
  ]
}

