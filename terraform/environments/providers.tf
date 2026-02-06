terraform {
  required_version = ">= 1.9.0"

  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.52"
    }
  }
}

# Workspace-based authentication (Azure Databricks pattern)
# Uses Azure CLI authentication automatically
provider "databricks" {
  host = var.databricks_workspace_host
  
  # Azure Databricks automatically uses az cli auth
  # No need for account_id - workspace provider can query metastores
}
