variable "enable_workspace_config" {
  description = "Enable workspace configuration"
  type        = bool
  default     = true
}

variable "enable_unity_catalog" {
  description = "Enable Unity Catalog workspace setting"
  type        = bool
  default     = true
}

variable "enable_ip_access_lists" {
  description = "Enable IP access lists"
  type        = bool
  default     = false
}

variable "enable_token_management" {
  description = "Enable token management"
  type        = bool
  default     = true
}

variable "enable_databricks_sql_serverless" {
  description = "Enable Databricks SQL serverless compute"
  type        = bool
  default     = true
}

variable "enable_serverless_compute" {
  description = "Enable serverless compute for notebooks"
  type        = bool
  default     = true
}

variable "max_token_lifetime_days" {
  description = "Maximum token lifetime in days (0 = unlimited)"
  type        = number
  default     = 90
  
  validation {
    condition     = var.max_token_lifetime_days >= 0 && var.max_token_lifetime_days <= 365
    error_message = "Token lifetime must be between 0 and 365 days"
  }
}

variable "additional_workspace_config" {
  description = "Additional workspace configuration settings"
  type        = map(string)
  default     = {}
}

variable "ip_access_lists" {
  description = "IP access lists to configure"
  type = map(object({
    list_type    = string       # "ALLOW" or "BLOCK"
    ip_addresses = list(string) # CIDR blocks
    enabled      = bool
  }))
  default = {}
}

variable "admin_groups" {
  description = "Admin groups to create"
  type = map(object({
    members = list(string)
  }))
  default = {}
}

variable "global_init_scripts" {
  description = "Global init scripts"
  type = map(object({
    enabled        = bool
    source         = string # Path to script file
    content        = string # Inline script content
    content_base64 = string # Base64 encoded content
    position       = number # Execution order
  }))
  default = {}
}

variable "shared_workspace_files" {
  description = "Shared workspace files to upload"
  type = map(object({
    source = string # Local file path
    path   = string # Workspace path
  }))
  default = {}
}

variable "workspace_folder_permissions" {
  description = "Permissions for workspace folders"
  type = map(object({
    access_controls = list(object({
      group_name       = string
      permission_level = string
    }))
  }))
  default = {}
}

variable "tags" {
  description = "Tags for workspace resources"
  type        = map(string)
  default     = {}
}
