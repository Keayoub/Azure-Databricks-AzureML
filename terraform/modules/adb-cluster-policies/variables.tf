variable "environment_name" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment_name)
    error_message = "Environment must be dev, staging, or prod"
  }
}

# ========== Policy Creation Flags ==========
variable "create_personal_compute_policy" {
  description = "Create personal compute policy for individual users"
  type        = bool
  default     = true
}

variable "create_shared_compute_policy" {
  description = "Create shared compute policy for teams"
  type        = bool
  default     = true
}

variable "create_production_jobs_policy" {
  description = "Create production jobs policy"
  type        = bool
  default     = true
}

variable "create_high_concurrency_policy" {
  description = "Create high concurrency policy for SQL analytics"
  type        = bool
  default     = true
}

# ========== Policy Settings ==========
variable "enable_cost_controls" {
  description = "Enable automatic cost control rules"
  type        = bool
  default     = true
}

variable "enable_security_hardening" {
  description = "Enable security hardening rules"
  type        = bool
  default     = true
}

variable "max_workers_limit" {
  description = "Maximum number of workers allowed across all policies"
  type        = number
  default     = 50
  
  validation {
    condition     = var.max_workers_limit >= 1 && var.max_workers_limit <= 100
    error_message = "Max workers limit must be between 1 and 100"
  }
}

variable "auto_termination_minutes" {
  description = "Default auto-termination timeout in minutes"
  type        = number
  default     = 30
  
  validation {
    condition     = var.auto_termination_minutes >= 5 && var.auto_termination_minutes <= 1440
    error_message = "Auto-termination must be between 5 minutes and 24 hours"
  }
}

variable "allowed_node_types" {
  description = "List of allowed VM types for clusters"
  type        = list(string)
  default     = [
    "Standard_DS3_v2",
    "Standard_DS4_v2",
    "Standard_D8s_v3",
    "Standard_D16s_v3"
  ]
}

variable "default_cost_center" {
  description = "Default cost center for resource tagging"
  type        = string
  default     = "Engineering"
}

variable "additional_policy_rules" {
  description = "Additional policy rules to merge with base policies"
  type        = any
  default     = {}
}

# ========== Custom Policies ==========
variable "custom_policies" {
  description = "Custom cluster policies to create"
  type = map(object({
    definition  = any
    description = string
  }))
  default = {}
}

# ========== Permissions ==========
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

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
