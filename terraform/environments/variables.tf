variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

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

variable "project_name" {
  description = "Project name for naming resources"
  type        = string
}

variable "shared_resource_group_name" {
  description = "Shared resource group name (from Bicep deployment)"
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
  description = "Databricks account ID"
  type        = string
}

variable "metastore_owner" {
  description = "Principal name that owns the metastore (AAD group)"
  type        = string
  default     = "account_unity_admin"
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

variable "storage_account_replication_type" {
  description = "Storage account replication type for UC metastore (e.g., LRS, GRS, RAGRS, ZRS)."
  type        = string
  default     = "LRS"
}
