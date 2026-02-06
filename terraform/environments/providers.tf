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
provider "databricks" {
  host = var.databricks_workspace_host
}
