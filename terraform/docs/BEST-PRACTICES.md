# Terraform Best Practices for This Project

## 🔄 Idempotency Enhancements

### 1. Import Blocks for Existing Resources
When resources might already exist (common during re-deployments), use import blocks to bring them under Terraform management without recreation:

```terraform
# In metastore/main.tf - Import existing metastore if found
import {
  to = databricks_metastore.primary[0]
  id = local.existing_id
  for_each = local.metastore_exists ? toset([local.existing_id]) : toset([])
}
```

### 2. Lifecycle Rules to Prevent Unwanted Changes
```terraform
# In modules/adb-uc-catalogs/main.tf
resource "databricks_catalog" "this" {
  for_each     = { for c in local.catalog_list : c.key => c }
  metastore_id = var.metastore_id
  name         = each.value.name
  comment      = each.value.comment
  force_destroy = true
  
  lifecycle {
    prevent_destroy = false  # Set true for production
    ignore_changes  = [
      # Ignore manual changes to these fields
      properties,
      owner  # If owners are managed outside Terraform
    ]
    create_before_destroy = false  # Important for unique names
  }
}
```

### 3. Data Sources Before Creation
Check if resources exist before creating:

```terraform
# Check if catalog already exists
data "databricks_catalogs" "existing" {}

locals {
  existing_catalog_names = [for c in data.databricks_catalogs.existing.catalogs : c.name]
  
  # Only create catalogs that don't exist
  catalogs_to_create = {
    for k, v in var.catalogs : k => v
    if !contains(local.existing_catalog_names, v.name)
  }
}
```

## 🔒 Security Enhancements

### 1. Mark Sensitive Variables
```terraform
# In environments/variables.tf
variable "databricks_workspace_host" {
  description = "Databricks workspace host URL"
  type        = string
  sensitive   = true  # Prevents output in logs
}

variable "databricks_account_id" {
  description = "Databricks account ID for account-level operations"
  type        = string
  sensitive   = true
}
```

### 2. Secure State Backend
```terraform
# In environments/providers.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstate${var.project_name}"
    container_name       = "tfstate"
    key                  = "databricks-uc.tfstate"
    
    # Security features
    use_azuread_auth         = true  # Use AAD instead of access keys
    use_oidc                 = true  # If using GitHub Actions
    use_encryption_at_rest   = true
  }
}
```

### 3. Least Privilege RBAC
```terraform
# Add variable for service principal instead of user accounts
variable "terraform_sp_object_id" {
  description = "Service Principal Object ID for Terraform operations"
  type        = string
  sensitive   = true
}

# Use service principal for owner assignments
resource "databricks_grants" "catalog_owner" {
  for_each = {
    for c in local.catalog_list : c.key => c
    if c.owner != null
  }
  catalog = databricks_catalog.this[each.key].name

  grant {
    principal  = var.terraform_sp_object_id  # Service Principal, not user
    privileges = ["USE_CATALOG", "CREATE_SCHEMA"]  # Minimal permissions
  }
}
```

### 4. Validate Inputs
```terraform
# In environments/variables.tf - Enhanced validation
variable "environment_name" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.environment_name))
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "catalogs" {
  description = "Map of catalogs to create"
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
  
  validation {
    condition = alltrue([
      for k, v in var.catalogs : can(regex("^[a-z0-9_]+$", v.name))
    ])
    error_message = "Catalog names must be lowercase alphanumeric with underscores only."
  }
}
```

## 🛡️ Safety Enhancements

### 1. Pre-commit Validation
```terraform
# Add to environments/main.tf
# Validation checks run before any operations
check "workspace_accessible" {
  assert {
    condition     = data.databricks_current_metastore.this.id != null
    error_message = "Cannot access workspace. Check authentication and network connectivity."
  }
}
```

### 2. Conditional Module Execution
```terraform
# In environments/main.tf - Add feature flags
variable "enable_uc_catalogs" {
  description = "Enable Unity Catalog management"
  type        = bool
  default     = true
}

module "uc_catalogs" {
  count  = var.enable_uc_catalogs ? 1 : 0
  source = "../modules/adb-uc-catalogs"
  
  metastore_id = local.metastore_id
  catalogs     = var.catalogs
  tags         = var.tags
}
```

### 3. Dependency Management
```terraform
# In modules/adb-uc-volumes/main.tf
resource "databricks_volume" "this" {
  for_each     = var.volumes
  catalog_name = each.value.catalog_name
  schema_name  = each.value.schema_name
  name         = each.value.name
  comment      = each.value.comment
  volume_type  = "EXTERNAL"
  
  # Explicit dependencies
  depends_on = [
    var.schema_dependencies  # Pass from catalog module
  ]
  
  lifecycle {
    # Prevent volume deletion before data migration
    prevent_destroy = true
  }
}
```

### 4. Output Sanitization
```terraform
# In environments/outputs.tf
output "metastore_id" {
  description = "Unity Catalog metastore ID"
  value       = local.metastore_id
  sensitive   = false  # OK to show IDs
}

output "workspace_url" {
  description = "Databricks workspace URL"
  value       = var.databricks_workspace_host
  sensitive   = true  # Don't log URLs
}

# Use structured outputs for programmatic access
output "catalog_info" {
  description = "Created catalog information"
  value = {
    for k, v in module.uc_catalogs.catalogs : k => {
      id   = v.id
      name = v.name
      # Don't expose owner info in outputs
    }
  }
}
```

## 📋 Recommended Workflow

### Development Cycle
```bash
# 1. Format code
terraform fmt -recursive

# 2. Validate syntax
terraform validate

# 3. Plan with output file
terraform plan -out=tfplan -var-file=terraform.tfvars

# 4. Review plan carefully
terraform show tfplan

# 5. Apply from plan file (idempotent)
terraform apply tfplan

# 6. Clean up plan file
rm tfplan
```

### Production Deployment
```bash
# 1. Use workspace per environment
terraform workspace new prod || terraform workspace select prod

# 2. Plan with detailed log
TF_LOG=INFO terraform plan -out=tfplan.prod -var-file=prod.tfvars 2>&1 | tee plan.log

# 3. Require approval (CI/CD)
# Manual approval gate here

# 4. Apply with auto-approve only in CI/CD
terraform apply tfplan.prod

# 5. Save outputs
terraform output -json > outputs.prod.json
```

## 🔍 State Management

### Remote State Locking
```terraform
# Prevents concurrent modifications
resource "azurerm_storage_account" "tfstate" {
  # Enable blob versioning for state history
  blob_properties {
    versioning_enabled = true
    
    delete_retention_policy {
      days = 30
    }
  }
}
```

### State Encryption
```terraform
# All Azure Storage accounts encrypt by default
# But you can use customer-managed keys
resource "azurerm_storage_account" "tfstate" {
  name                     = "sttfstate${var.project_name}"
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = var.azure_region
  account_tier             = "Standard"
  account_replication_type = "GRS"
  
  # Customer-managed encryption
  customer_managed_key {
    key_vault_key_id          = azurerm_key_vault_key.tfstate.id
    user_assigned_identity_id = azurerm_user_assigned_identity.tfstate.id
  }
  
  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.tfstate.id]
  }
}
```

## 🎯 Module-Specific Improvements

### Skip Existing Resources Pattern
```terraform
# modules/adb-uc-catalogs/main.tf
# Query existing catalogs first
data "databricks_catalogs" "all" {}

locals {
  existing_catalogs = toset([for c in data.databricks_catalogs.all.catalogs : c.name])
  
  # Create only if doesn't exist
  catalogs_to_manage = {
    for k, v in var.catalogs : k => v
    if !contains(local.existing_catalogs, v.name) || var.force_manage
  }
}

resource "databricks_catalog" "this" {
  for_each     = local.catalogs_to_manage
  metastore_id = var.metastore_id
  name         = each.value.name
  comment      = each.value.comment
  force_destroy = var.environment_name != "prod"  # Safety for production
}
```

### Error Handling
```terraform
# Add preconditions to resources
resource "databricks_catalog" "this" {
  for_each     = { for c in local.catalog_list : c.key => c }
  
  lifecycle {
    precondition {
      condition     = var.metastore_id != null && var.metastore_id != ""
      error_message = "Metastore ID must be provided. Run metastore deployment first."
    }
    
    precondition {
      condition     = can(regex("^[a-z0-9_]+$", each.value.name))
      error_message = "Catalog name '${each.value.name}' is invalid. Use lowercase letters, numbers, and underscores only."
    }
  }
  
  metastore_id = var.metastore_id
  name         = each.value.name
  comment      = each.value.comment
  force_destroy = true
}
```

## 📚 Additional Recommendations

1. **Use .terraform.lock.hcl**: Commit to version control for consistent provider versions (HCL = HashiCorp Configuration Language)
2. **Enable detailed logging**: `TF_LOG=DEBUG` for troubleshooting
3. **Separate environments**: Use workspaces or separate state files
4. **Document changes**: Use `terraform show -json tfplan > plan.json` for auditing
5. **Regular state backups**: Azure Storage versioning provides automatic backups
6. **Use terraform-docs**: Auto-generate module documentation
7. **Implement drift detection**: Regular `terraform plan` runs in CI/CD
8. **Use Sentinel/OPA**: Policy-as-code for governance (advanced)

## 🚨 Common Pitfalls to Avoid

1. ❌ **Never store secrets in code** - Use Azure Key Vault references
2. ✅ **Review Key Vault patterns** - See [DATABRICKS-KEYVAULT-ARCHITECTURE-GUIDE.md](../../docs/DATABRICKS-KEYVAULT-ARCHITECTURE-GUIDE.md)
3. ❌ **Don't use `-auto-approve` locally** - Always review plans
4. ❌ **Don't modify state files manually** - Use `terraform state` commands
5. ❌ **Don't share service principal credentials** - Use OIDC/managed identity
6. ❌ **Don't ignore plan warnings** - They indicate potential issues
7. ❌ **Don't run concurrent applies** - State locking prevents this
8. ❌ **Don't delete state files** - They're your source of truth
9. ❌ **Don't skip testing** - Use `terraform plan` before every apply
