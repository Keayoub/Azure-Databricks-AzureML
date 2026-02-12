variable "environment_name" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment_name)
    error_message = "Environment must be dev, staging, or prod"
  }
}

# ========== Databricks-Backed Secret Scopes ==========
variable "databricks_backed_scopes" {
  description = "Databricks-backed secret scopes to create"
  type = map(object({
    secrets = map(string) # key-value pairs
    acls = list(object({
      principal  = string # Group or user name
      permission = string # READ, WRITE, MANAGE
    }))
  }))
  default = {}
  
  sensitive = true
}

# ========== Azure Key Vault-Backed Secret Scopes ==========
variable "keyvault_backed_scopes" {
  description = "Azure Key Vault-backed secret scopes to create"
  type = map(object({
    keyvault_resource_id = string # Azure Key Vault resource ID
    keyvault_dns_name    = string # Key Vault DNS name (e.g., https://mykv.vault.azure.net/)
    acls = list(object({
      principal  = string
      permission = string
    }))
  }))
  default = {}
}

# ========== Pre-configured Scopes ==========
variable "create_application_secrets_scope" {
  description = "Create application secrets scope"
  type        = bool
  default     = true
}

variable "application_secrets_acls" {
  description = "ACLs for application secrets scope"
  type = map(object({
    principal  = string
    permission = string
  }))
  default = {}
}

variable "create_data_sources_scope" {
  description = "Create data sources credentials scope"
  type        = bool
  default     = true
}

variable "data_sources_acls" {
  description = "ACLs for data sources scope"
  type = map(object({
    principal  = string
    permission = string
  }))
  default = {}
}

variable "create_api_keys_scope" {
  description = "Create API keys scope"
  type        = bool
  default     = false
}

variable "api_keys_acls" {
  description = "ACLs for API keys scope"
  type = map(object({
    principal  = string
    permission = string
  }))
  default = {}
}

variable "tags" {
  description = "Tags for resources (informational only)"
  type        = map(string)
  default     = {}
}
