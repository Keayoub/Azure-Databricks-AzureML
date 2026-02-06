# ========================================
# Metastore Module Variables
# ========================================

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "azure_region" {
  description = "Azure region for resources"
  type        = string
}

variable "environment_name" {
  description = "Environment name (dev/staging/prod)"
  type        = string
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
  type        = string
}

variable "databricks_workspace_host" {
  description = "Databricks workspace URL (https://...)"
  type        = string
}

variable "databricks_account_id" {
  description = "Databricks account ID (for account-level APIs)"
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
