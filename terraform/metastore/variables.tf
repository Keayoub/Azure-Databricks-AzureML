# ========================================
# Metastore Module Variables
# ========================================

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  sensitive   = true
  
  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "Subscription ID must be a valid GUID."
  }
}

variable "azure_region" {
  description = "Azure region for resources"
  type        = string
}

variable "project_name" {
  description = "Project name (e.g., dbxaml)"
  type        = string
}

variable "environment_name" {
  description = "Environment name (dev/staging/prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment_name)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "shared_resource_group_name" {
  description = "Resource group name for shared resources (storage)"
  type        = string
}

variable "databricks_resource_group_name" {
  description = "Resource group name for Databricks workspace"
  type        = string
}

variable "databricks_workspace_id" {
  description = "Databricks workspace ID (numeric)"
  type        = number
}

variable "databricks_workspace_host" {
  description = "Databricks workspace URL (https://...)"
  type        = string
  sensitive   = true
  
  validation {
    condition     = can(regex("^https://", var.databricks_workspace_host))
    error_message = "Workspace host must be a valid HTTPS URL."
  }
}

variable "databricks_account_id" {
  description = "Databricks account ID (for account-level APIs)"
  type        = string
  sensitive   = true
}

variable "databricks_region" {
  description = "Databricks region code (e.g., ca-central-1 for Canada Central)"
  type        = string
}

variable "metastore_storage_name" {
  description = "Storage account name for metastore"
  type        = string
}

variable "access_connector_name" {
  description = "Access connector name for Unity Catalog"
  type        = string
}
