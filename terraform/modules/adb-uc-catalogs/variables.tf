variable "metastore_id" {
  description = "ID of the UC metastore"
  type        = string
}

variable "catalogs" {
  description = "Map of catalog definitions to create"
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
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "skip_existing_resources" {
  description = "Skip creating resources that already exist (idempotent mode)"
  type        = bool
  default     = true
}

variable "environment_name" {
  description = "Environment name for safety controls (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment_name)
    error_message = "Environment must be dev, staging, or prod."
  }
}

locals {
  # Flatten catalogs and schemas for easier resource creation
  catalog_list = [
    for catalog_key, catalog in var.catalogs : {
      key     = catalog_key
      name    = catalog.name
      comment = catalog.comment
      owner   = catalog.owner
    }
  ]

  schema_list = flatten([
    for catalog_key, catalog in var.catalogs : [
      for schema_key, schema in catalog.schemas : {
        catalog_key  = catalog_key
        catalog_name = catalog.name
        schema_key   = schema_key
        name         = schema.name
        comment      = schema.comment
        owner        = schema.owner
      }
    ]
  ])
}
