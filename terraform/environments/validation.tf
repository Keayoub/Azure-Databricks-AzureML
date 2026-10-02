# ========================================
# Terraform Validation Checks
# ========================================
# Runtime validation to ensure safe deployments

# Check 1: Workspace Connectivity
check "workspace_accessible" {
  assert {
    condition     = data.databricks_current_metastore.this.id != null && data.databricks_current_metastore.this.id != ""
    error_message = <<-EOT
      Cannot access Databricks workspace metastore.
      Verify:
      1. Azure CLI authentication: az account show
      2. Network connectivity to workspace
      3. databricks_workspace_host is correct
    EOT
  }
}

# Check 2: Catalog Name Validation
check "catalog_names_valid" {
  assert {
    condition = alltrue([
      for k, v in var.catalogs : can(regex("^[a-z0-9_]{3,255}$", v.name))
    ])
    error_message = "Catalog names must be 3-255 characters, lowercase letters, numbers, and underscores only."
  }
}

# Check 3: Environment Consistency
check "environment_consistency" {
  assert {
    condition     = contains(["dev", "staging", "prod"], var.environment_name)
    error_message = "environment_name must be dev, staging, or prod."
  }
}

# Check 4: No Duplicate Catalog Names
check "no_duplicate_catalogs" {
  assert {
    condition     = length([for k, v in var.catalogs : v.name]) == length(distinct([for k, v in var.catalogs : v.name]))
    error_message = "Duplicate catalog names detected. Each catalog must have a unique name."
  }
}
