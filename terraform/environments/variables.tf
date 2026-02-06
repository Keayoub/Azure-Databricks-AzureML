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
