# ========================================
# Databricks Workspace Configuration Module
# ========================================
# Purpose: Configure workspace-level settings, IP access lists, tokens
# Scope: Workspace configuration
# Dependencies: Databricks workspace must exist

terraform {
  required_version = ">= 1.0"
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.0"
    }
  }
}

# ========== Data Source: Current User ==========
data "databricks_current_user" "me" {}

# ========== Workspace Configuration ==========
resource "databricks_workspace_conf" "this" {
  count = var.enable_workspace_config ? 1 : 0

  custom_config = merge(
    {
      # Enable Unity Catalog
      "enableUnityGuarantee" = var.enable_unity_catalog

      # Security settings
      "enableIpAccessLists"           = var.enable_ip_access_lists
      "enableTokensConfig"            = var.enable_token_management
      "enableDeprecatedClusterNamedInitScripts" = false
      "enableDeprecatedGlobalInitScripts"       = false
      
      # Cluster settings
      "enableDcs"                     = var.enable_databricks_sql_serverless
      "enableServerlessCompute"       = var.enable_serverless_compute
      
      # Notebook settings
      "enableNotebookTableClipboard" = true
      "maxTokenLifetimeDays"         = tostring(var.max_token_lifetime_days)
    },
    var.additional_workspace_config
  )
}

# ========== IP Access Lists ==========
resource "databricks_ip_access_list" "allowed_ips" {
  for_each = var.enable_ip_access_lists ? var.ip_access_lists : {}

  list_type    = each.value.list_type
  label        = each.key
  ip_addresses = each.value.ip_addresses
  enabled      = each.value.enabled
}

# ========== Workspace Admin Groups (optional) ==========
resource "databricks_group" "admin_groups" {
  for_each = var.admin_groups

  display_name = each.key
}

resource "databricks_group_member" "admin_group_members" {
  for_each = {
    for membership in local.admin_group_memberships : "${membership.group}_${membership.member}" => membership
  }

  group_id  = databricks_group.admin_groups[each.value.group].id
  member_id = each.value.member_id
}

locals {
  admin_group_memberships = flatten([
    for group_name, group_config in var.admin_groups : [
      for member in group_config.members : {
        group     = group_name
        member    = member
        member_id = member
      }
    ]
  ])
}

# ========== Global Init Scripts ==========
resource "databricks_global_init_script" "init_scripts" {
  for_each = var.global_init_scripts

  name    = each.key
  enabled = each.value.enabled
  source  = each.value.source != "" ? each.value.source : null
  content_base64 = each.value.content_base64 != "" ? each.value.content_base64 : (
    each.value.content != "" ? base64encode(each.value.content) : null
  )

  # Position determines execution order
  position = each.value.position
}

# ========== Workspace Files (for shared utilities) ==========
resource "databricks_workspace_file" "shared_files" {
  for_each = var.shared_workspace_files

  source = each.value.source
  path   = each.value.path
}

# ========== Notebook Permissions (example) ==========
resource "databricks_permissions" "workspace_folder" {
  for_each = var.workspace_folder_permissions

  directory_path = each.key

  dynamic "access_control" {
    for_each = each.value.access_controls
    content {
      group_name       = access_control.value.group_name
      permission_level = access_control.value.permission_level
    }
  }
}

# ========== Outputs ==========
output "workspace_url" {
  description = "Databricks workspace URL"
  value       = "Workspace configuration applied"
}

output "ip_access_lists" {
  description = "IP access lists created"
  value       = { for k, v in databricks_ip_access_list.allowed_ips : k => v.id }
}

output "admin_groups" {
  description = "Admin groups created"
  value       = { for k, v in databricks_group.admin_groups : k => v.id }
}

output "global_init_scripts" {
  description = "Global init scripts created"
  value       = { for k, v in databricks_global_init_script.init_scripts : k => v.id }
}
