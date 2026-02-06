variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where UC resources will be created"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "environment_name" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "databricks_workspace_id" {
  description = "Databricks workspace ID (from Bicep deployment)"
  type        = string
}

variable "databricks_workspace_host" {
  description = "Databricks workspace host URL (from Bicep deployment)"
  type        = string
}

variable "databricks_account_id" {
  description = "Databricks account ID for account-level operations"
  type        = string
}

variable "metastore_owner" {
  description = "Name of the principal that will own the metastore (AAD group name)"
  type        = string
  default     = "account_unity_admin"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "storage_account_replication_type" {
  description = "Storage account replication type (e.g., LRS, GRS, RAGRS, ZRS)."
  type        = string
  default     = "LRS"
}

locals {
  name_prefix              = "${var.project_name}-${var.environment_name}"
  storage_account_name     = replace("st${var.project_name}${var.environment_name}uc", "-", "")
  access_connector_name    = "ac-${local.name_prefix}-uc"
  metastore_container_name = "uc-metastore"
}
