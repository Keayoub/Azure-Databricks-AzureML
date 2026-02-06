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
  
  # Use CLI authentication
  use_cli = true
}

# Databricks workspace provider with Azure authentication
# This single provider handles both workspace and account-level operations in Azure Databricks
provider "databricks" {
  alias = "workspace"
  host  = var.databricks_workspace_host
}

# Account-level alias points to the same workspace provider
# In Azure Databricks, account-level operations use workspace authentication
provider "databricks" {
  alias = "account"
  host  = var.databricks_workspace_host
}
