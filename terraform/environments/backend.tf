# ========================================
# Terraform Backend Configuration
# ========================================
# Secure remote state with Azure Storage

terraform {
  backend "azurerm" {
    # Configure via environment variables or backend config file:
    # export ARM_RESOURCE_GROUP_NAME="rg-terraform-state"
    # export ARM_STORAGE_ACCOUNT_NAME="sttfstate<project>"
    # export ARM_CONTAINER_NAME="tfstate"
    # export ARM_KEY="databricks-uc.tfstate"
    
    # Or use -backend-config file:
    # terraform init -backend-config=backend.conf
    
    # Security features
    use_azuread_auth = true  # Use Azure AD auth instead of access keys
    
    # Uncomment for GitHub Actions with OIDC:
    # use_oidc = true
  }
}

# Example backend.conf file (create separately, don't commit):
# resource_group_name  = "rg-terraform-state"
# storage_account_name = "sttfstate<yourproject>"
# container_name       = "tfstate"
# key                  = "databricks-uc.tfstate"
