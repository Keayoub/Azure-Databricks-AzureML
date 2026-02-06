terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.52"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
  
  # Use managed identity (Terraform running with User-Assigned MI from access connector)
  # This avoids key-based authentication issues
  use_cli = true
}

# Databricks account-level provider (for metastore operations)
provider "databricks" {
  alias      = "account"
  host       = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_account_id
  auth_type  = "azure-cli"
}

# Databricks workspace-level provider (for workspace resources)
provider "databricks" {
  alias = "workspace"
  host  = var.databricks_workspace_host
  auth_type = "azure-cli"
}
