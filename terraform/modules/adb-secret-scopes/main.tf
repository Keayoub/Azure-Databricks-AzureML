# ========================================
# Databricks Secret Scopes Module
# ========================================
# Purpose: Create and manage secret scopes for secure credential storage
# Types: Databricks-backed and Azure Key Vault-backed scopes

terraform {
  required_version = ">= 1.0"
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# ========== Data Sources ==========
data "databricks_current_user" "me" {}

# ========== Databricks-Backed Secret Scopes ==========
# These scopes store secrets in Databricks' internal encrypted storage

resource "databricks_secret_scope" "databricks_backed" {
  for_each = var.databricks_backed_scopes

  name = each.key

  # Databricks-backed scopes don't have keyvault_metadata
}

# ========== Azure Key Vault-Backed Secret Scopes ==========
# These scopes reference secrets stored in Azure Key Vault

resource "databricks_secret_scope" "keyvault_backed" {
  for_each = var.keyvault_backed_scopes

  name = each.key

  keyvault_metadata {
    resource_id = each.value.keyvault_resource_id
    dns_name    = each.value.keyvault_dns_name
  }
}

# ========== Secrets for Databricks-Backed Scopes ==========
resource "databricks_secret" "databricks_backed_secrets" {
  for_each = {
    for secret in local.databricks_backed_secrets : "${secret.scope}_${secret.key}" => secret
  }

  scope        = databricks_secret_scope.databricks_backed[each.value.scope].name
  key          = each.value.key
  string_value = each.value.value
}

locals {
  # Flatten secrets for Databricks-backed scopes
  databricks_backed_secrets = flatten([
    for scope_name, scope_config in var.databricks_backed_scopes : [
      for secret_key, secret_value in scope_config.secrets : {
        scope = scope_name
        key   = secret_key
        value = secret_value
      }
    ]
  ])
}

# ========== ACLs for Databricks-Backed Scopes ==========
resource "databricks_secret_acl" "databricks_backed_acls" {
  for_each = {
    for acl in local.databricks_backed_acls : "${acl.scope}_${acl.principal}" => acl
  }

  scope      = databricks_secret_scope.databricks_backed[each.value.scope].name
  principal  = each.value.principal
  permission = each.value.permission
}

locals {
  # Flatten ACLs for Databricks-backed scopes
  databricks_backed_acls = flatten([
    for scope_name, scope_config in var.databricks_backed_scopes : [
      for acl in scope_config.acls : {
        scope      = scope_name
        principal  = acl.principal
        permission = acl.permission
      }
    ]
  ])
}

# ========== ACLs for Key Vault-Backed Scopes ==========
resource "databricks_secret_acl" "keyvault_backed_acls" {
  for_each = {
    for acl in local.keyvault_backed_acls : "${acl.scope}_${acl.principal}" => acl
  }

  scope      = databricks_secret_scope.keyvault_backed[each.value.scope].name
  principal  = each.value.principal
  permission = each.value.permission
}

locals {
  # Flatten ACLs for Key Vault-backed scopes
  keyvault_backed_acls = flatten([
    for scope_name, scope_config in var.keyvault_backed_scopes : [
      for acl in scope_config.acls : {
        scope      = scope_name
        principal  = acl.principal
        permission = acl.permission
      }
    ]
  ])
}

# ========== Pre-configured Secret Scopes ==========

# Application Secrets (Databricks-backed)
resource "databricks_secret_scope" "application_secrets" {
  count = var.create_application_secrets_scope ? 1 : 0

  name = "${var.environment_name}-app-secrets"
}

resource "databricks_secret_acl" "application_secrets_acls" {
  for_each = var.create_application_secrets_scope ? var.application_secrets_acls : {}

  scope      = databricks_secret_scope.application_secrets[0].name
  principal  = each.value.principal
  permission = each.value.permission
}

# Data Sources Credentials (Databricks-backed)
resource "databricks_secret_scope" "data_sources" {
  count = var.create_data_sources_scope ? 1 : 0

  name = "${var.environment_name}-data-sources"
}

resource "databricks_secret_acl" "data_sources_acls" {
  for_each = var.create_data_sources_scope ? var.data_sources_acls : {}

  scope      = databricks_secret_scope.data_sources[0].name
  principal  = each.value.principal
  permission = each.value.permission
}

# API Keys (Databricks-backed)
resource "databricks_secret_scope" "api_keys" {
  count = var.create_api_keys_scope ? 1 : 0

  name = "${var.environment_name}-api-keys"
}

resource "databricks_secret_acl" "api_keys_acls" {
  for_each = var.create_api_keys_scope ? var.api_keys_acls : {}

  scope      = databricks_secret_scope.api_keys[0].name
  principal  = each.value.principal
  permission = each.value.permission
}

# ========== Outputs ==========
output "databricks_backed_scopes" {
  description = "Databricks-backed secret scope names"
  value       = { for k, v in databricks_secret_scope.databricks_backed : k => v.name }
}

output "keyvault_backed_scopes" {
  description = "Key Vault-backed secret scope names"
  value       = { for k, v in databricks_secret_scope.keyvault_backed : k => v.name }
}

output "application_secrets_scope" {
  description = "Application secrets scope name"
  value       = var.create_application_secrets_scope ? databricks_secret_scope.application_secrets[0].name : null
}

output "data_sources_scope" {
  description = "Data sources scope name"
  value       = var.create_data_sources_scope ? databricks_secret_scope.data_sources[0].name : null
}

output "api_keys_scope" {
  description = "API keys scope name"
  value       = var.create_api_keys_scope ? databricks_secret_scope.api_keys[0].name : null
}
