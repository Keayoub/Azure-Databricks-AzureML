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

output "all_scopes" {
  description = "All secret scope names"
  value = merge(
    { for k, v in databricks_secret_scope.databricks_backed : k => v.name },
    { for k, v in databricks_secret_scope.keyvault_backed : k => v.name },
    var.create_application_secrets_scope ? { application_secrets = databricks_secret_scope.application_secrets[0].name } : {},
    var.create_data_sources_scope ? { data_sources = databricks_secret_scope.data_sources[0].name } : {},
    var.create_api_keys_scope ? { api_keys = databricks_secret_scope.api_keys[0].name } : {}
  )
}
