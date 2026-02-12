variable "azure_region" {
  description = "Azure region for UC resources"
  type        = string
  default     = "Canada East"
}

variable "environment_name" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment_name)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "databricks_workspace_host" {
  description = "Databricks workspace host URL (from Bicep deployment)"
  type        = string
  sensitive   = true  # Prevent logging of workspace URLs
  
  validation {
    condition     = can(regex("^https://", var.databricks_workspace_host))
    error_message = "Workspace host must be a valid HTTPS URL."
  }
}

variable "catalogs" {
  description = "Map of catalogs to create with their schemas"
  type = map(object({
    name    = string
    comment = optional(string, "")
    owner   = optional(string, null)
    schemas = optional(map(object({
      name    = string
      comment = optional(string, "")
      owner   = optional(string, null)
    })), {})
  }))
  default = {
    main = {
      name    = "main"
      comment = "Default catalog"
      owner   = null
      schemas = {}
    }
  }
  
  validation {
    condition = alltrue([
      for k, v in var.catalogs : can(regex("^[a-z0-9_]{3,255}$", v.name))
    ])
    error_message = "Catalog names must be 3-255 chars, lowercase letters, numbers, and underscores only."
  }
}

variable "volumes" {
  description = "Map of volumes to create"
  type = map(object({
    catalog_name = string
    schema_name  = string
    name         = string
    comment      = optional(string, "")
    owner        = optional(string, null)
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    "project" : "databricks-azureml"
    "managed-by" : "terraform"
  }
}

variable "enable_catalog_management" {
  description = "Enable Unity Catalog management (set to false to skip catalog creation)"
  type        = bool
  default     = true
}

variable "enable_volume_management" {
  description = "Enable volume management (set to false to skip volume creation)"
  type        = bool
  default     = true
}

variable "skip_existing_resources" {
  description = "Skip resources that already exist (idempotent mode)"
  type        = bool
  default     = true
}

# ========================================
# Databricks Operational Configuration Variables
# ========================================

# ========== Workspace Configuration ==========
variable "enable_workspace_configuration" {
  description = "Enable Databricks workspace configuration"
  type        = bool
  default     = true
}

variable "enable_serverless_compute" {
  description = "Enable serverless compute for notebooks"
  type        = bool
  default     = true
}

variable "enable_databricks_sql_serverless" {
  description = "Enable Databricks SQL serverless compute"
  type        = bool
  default     = true
}

variable "max_token_lifetime_days" {
  description = "Maximum token lifetime in days (0 = unlimited)"
  type        = number
  default     = 90
}

variable "enable_ip_access_lists" {
  description = "Enable IP access lists for workspace"
  type        = bool
  default     = false
}

variable "ip_access_lists" {
  description = "IP access lists configuration"
  type = map(object({
    list_type    = string
    ip_addresses = list(string)
    enabled      = bool
  }))
  default = {}
}

variable "global_init_scripts" {
  description = "Global init scripts for all clusters"
  type = map(object({
    enabled        = bool
    source         = string
    content        = string
    content_base64 = string
    position       = number
  }))
  default = {}
}

# ========== Cluster Policies ==========
variable "enable_cluster_policies" {
  description = "Enable cluster policies management"
  type        = bool
  default     = true
}

variable "create_personal_compute_policy" {
  description = "Create personal compute policy"
  type        = bool
  default     = true
}

variable "create_shared_compute_policy" {
  description = "Create shared compute policy"
  type        = bool
  default     = true
}

variable "create_production_jobs_policy" {
  description = "Create production jobs policy"
  type        = bool
  default     = true
}

variable "create_high_concurrency_policy" {
  description = "Create high concurrency policy"
  type        = bool
  default     = false
}

variable "enable_cost_controls" {
  description = "Enable cost control rules in policies"
  type        = bool
  default     = true
}

variable "max_workers_limit" {
  description = "Maximum workers limit across all policies"
  type        = number
  default     = 50
}

variable "auto_termination_minutes" {
  description = "Default auto-termination timeout in minutes"
  type        = number
  default     = 30
}

variable "enable_security_hardening" {
  description = "Enable security hardening in policies"
  type        = bool
  default     = true
}

variable "personal_compute_permissions" {
  description = "Permissions for personal compute policy"
  type = list(object({
    group_name       = string
    permission_level = string
  }))
  default = []
}

variable "shared_compute_permissions" {
  description = "Permissions for shared compute policy"
  type = list(object({
    group_name       = string
    permission_level = string
  }))
  default = []
}

variable "production_jobs_permissions" {
  description = "Permissions for production jobs policy"
  type = list(object({
    group_name       = string
    permission_level = string
  }))
  default = []
}

# ========== Instance Pools ==========
variable "enable_instance_pools" {
  description = "Enable instance pools management"
  type        = bool
  default     = true
}

variable "create_general_purpose_pool" {
  description = "Create general purpose instance pool"
  type        = bool
  default     = true
}

variable "create_high_memory_pool" {
  description = "Create high memory instance pool"
  type        = bool
  default     = false
}

variable "create_compute_optimized_pool" {
  description = "Create compute optimized instance pool"
  type        = bool
  default     = false
}

variable "create_gpu_pool" {
  description = "Create GPU instance pool"
  type        = bool
  default     = false
}

variable "idle_instance_autotermination_minutes" {
  description = "Minutes before idle pool instances are terminated"
  type        = number
  default     = 15
}

variable "enable_spot_instances" {
  description = "Enable spot instances for cost savings"
  type        = bool
  default     = false
}

variable "azure_availability" {
  description = "Azure availability type for pools"
  type        = string
  default     = "ON_DEMAND_AZURE"
}

variable "general_purpose_min_idle" {
  description = "Minimum idle instances in general purpose pool"
  type        = number
  default     = 0
}

variable "general_purpose_max_capacity" {
  description = "Maximum capacity of general purpose pool"
  type        = number
  default     = 10
}

variable "general_purpose_pool_permissions" {
  description = "Permissions for general purpose pool"
  type = list(object({
    group_name       = string
    permission_level = string
  }))
  default = []
}

# ========== Secret Scopes ==========
variable "enable_secret_scopes" {
  description = "Enable secret scopes management"
  type        = bool
  default     = true
}

variable "create_application_secrets_scope" {
  description = "Create application secrets scope"
  type        = bool
  default     = true
}

variable "create_data_sources_scope" {
  description = "Create data sources credentials scope"
  type        = bool
  default     = true
}

variable "create_api_keys_scope" {
  description = "Create API keys scope"
  type        = bool
  default     = false
}

variable "application_secrets_acls" {
  description = "ACLs for application secrets scope"
  type = map(object({
    principal  = string
    permission = string
  }))
  default = {}
}

variable "data_sources_acls" {
  description = "ACLs for data sources scope"
  type = map(object({
    principal  = string
    permission = string
  }))
  default = {}
}

variable "api_keys_acls" {
  description = "ACLs for API keys scope"
  type = map(object({
    principal  = string
    permission = string
  }))
  default = {}
}

variable "databricks_backed_scopes" {
  description = "Databricks-backed secret scopes"
  type = map(object({
    secrets = map(string)
    acls = list(object({
      principal  = string
      permission = string
    }))
  }))
  default   = {}
  sensitive = true
}

variable "keyvault_backed_scopes" {
  description = "Azure Key Vault-backed secret scopes"
  type = map(object({
    keyvault_resource_id = string
    keyvault_dns_name    = string
    acls = list(object({
      principal  = string
      permission = string
    }))
  }))
  default = {}
}
