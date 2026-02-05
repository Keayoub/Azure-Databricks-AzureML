terraform {
  required_version = ">= 1.3"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.70"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.30"
    }
  }

  # Remote backend configuration - uncomment after first apply
  # backend "azurerm" {
  #   resource_group_name  = "rg-dev-dbxaml-shared"
  #   storage_account_name = "stdbxamldevq3a3hmrnwgh3m" # Replace with your shared storage account
  #   container_name       = "terraform"
  #   key                  = "databricks-uc/terraform.tfstate"
  # }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

provider "databricks" {
  host      = var.databricks_workspace_host
  auth_type = "azure-cli"
}

provider "databricks" {
  alias      = "account"
  host       = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_account_id
  auth_type  = "azure-cli"
}

