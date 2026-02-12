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

# ========================================
# Databricks Operational Configuration
# ========================================
# Purpose: Configure workspace settings, policies, pools, and secrets
# Deployed during: azd deploy (after Unity Catalog setup)

locals {
  # Operational deployment flags
  deploy_workspace_config = var.enable_workspace_configuration
  deploy_cluster_policies = var.enable_cluster_policies
  deploy_instance_pools   = var.enable_instance_pools
  deploy_secret_scopes    = var.enable_secret_scopes
}

# ========== Workspace Configuration Module ==========
module "workspace_config" {
  count  = local.deploy_workspace_config ? 1 : 0
  source = "../modules/adb-workspace-config"

  enable_workspace_config         = true
  enable_unity_catalog           = var.enable_catalog_management
  enable_serverless_compute      = var.enable_serverless_compute
  enable_databricks_sql_serverless = var.enable_databricks_sql_serverless
  max_token_lifetime_days        = var.max_token_lifetime_days
  enable_ip_access_lists         = var.enable_ip_access_lists
  ip_access_lists                = var.ip_access_lists
  global_init_scripts            = var.global_init_scripts
  
  tags = var.tags
}

# ========== Cluster Policies Module ==========
module "cluster_policies" {
  count  = local.deploy_cluster_policies ? 1 : 0
  source = "../modules/adb-cluster-policies"

  environment_name = var.environment_name

  # Built-in policies
  create_personal_compute_policy   = var.create_personal_compute_policy
  create_shared_compute_policy     = var.create_shared_compute_policy
  create_production_jobs_policy    = var.create_production_jobs_policy
  create_high_concurrency_policy   = var.create_high_concurrency_policy

  # Cost controls
  enable_cost_controls     = var.enable_cost_controls
  max_workers_limit        = var.max_workers_limit
  auto_termination_minutes = var.auto_termination_minutes
  
  # Security
  enable_security_hardening = var.enable_security_hardening
  
  # Permissions
  personal_compute_permissions = var.personal_compute_permissions
  shared_compute_permissions   = var.shared_compute_permissions
  production_jobs_permissions  = var.production_jobs_permissions

  tags = var.tags
}

# ========== Instance Pools Module ==========
module "instance_pools" {
  count  = local.deploy_instance_pools ? 1 : 0
  source = "../modules/adb-instance-pools"

  environment_name = var.environment_name

  # Pool creation flags
  create_general_purpose_pool    = var.create_general_purpose_pool
  create_high_memory_pool        = var.create_high_memory_pool
  create_compute_optimized_pool  = var.create_compute_optimized_pool
  create_gpu_pool                = var.create_gpu_pool

  # General settings
  idle_instance_autotermination_minutes = var.idle_instance_autotermination_minutes
  enable_spot_instances                 = var.enable_spot_instances
  azure_availability                    = var.azure_availability

  # Pool-specific settings
  general_purpose_min_idle     = var.general_purpose_min_idle
  general_purpose_max_capacity = var.general_purpose_max_capacity
  
  # Permissions
  general_purpose_pool_permissions = var.general_purpose_pool_permissions
  
  tags = var.tags
}

# ========== Secret Scopes Module ==========
module "secret_scopes" {
  count  = local.deploy_secret_scopes ? 1 : 0
  source = "../modules/adb-secret-scopes"

  environment_name = var.environment_name

  # Pre-configured scopes
  create_application_secrets_scope = var.create_application_secrets_scope
  create_data_sources_scope        = var.create_data_sources_scope
  create_api_keys_scope            = var.create_api_keys_scope

  # ACL configurations
  application_secrets_acls = var.application_secrets_acls
  data_sources_acls        = var.data_sources_acls
  api_keys_acls            = var.api_keys_acls

  # Custom scopes
  databricks_backed_scopes = var.databricks_backed_scopes
  keyvault_backed_scopes   = var.keyvault_backed_scopes

  tags = var.tags
}

