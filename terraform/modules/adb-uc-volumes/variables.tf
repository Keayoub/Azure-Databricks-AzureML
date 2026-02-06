variable "volumes" {
  description = "Map of volume definitions to create"
  type = map(object({
    catalog_name = string
    schema_name  = string
    name         = string
    comment      = optional(string, "")
    owner        = optional(string, null)
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
