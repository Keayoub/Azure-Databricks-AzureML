#!/bin/bash

# Deployment script for Secure Databricks Azure ML IaC
# This script automates the deployment process with validation and testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI not found. Install from: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    print_success "Azure CLI installed"
    
    # Check azd
    if ! command -v azd &> /dev/null; then
        print_error "Azure Developer CLI not found. Install from: https://aka.ms/install-azd"
        exit 1
    fi
    print_success "Azure Developer CLI installed"
    
    # Check Bicep
    if ! az bicep version &> /dev/null; then
        print_error "Bicep CLI not available"
        exit 1
    fi
    print_success "Bicep CLI available"
    
    # Check Azure login
    if ! az account show &> /dev/null; then
        print_warning "Not logged into Azure. Running 'az login'..."
        az login
    fi
    print_success "Azure CLI authenticated"
}

setup_environment() {
    print_header "Setting Up Environment"
    
    # Get subscription info
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    TENANT_ID=$(az account show --query tenantId -o tsv)
    
    print_success "Subscription ID: $SUBSCRIPTION_ID"
    
    # Get user object ID
    OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
    print_success "Admin Object ID: $OBJECT_ID"
    
    # Save to environment
    export SUBSCRIPTION_ID
    export TENANT_ID
    export ADMIN_OBJECT_ID=$OBJECT_ID
}

validate_bicep() {
    print_header "Validating Bicep Templates"
    
    if ! az bicep validate --file infra/main.bicep &> /dev/null; then
        print_error "Bicep validation failed for main.bicep"
        exit 1
    fi
    print_success "main.bicep validated"
    
    if ! az bicep build-params --file infra/main.bicepparam &> /dev/null; then
        print_error "Bicep validation failed for main.bicepparam"
        exit 1
    fi
    print_success "main.bicepparam validated"
}

update_parameters() {
    print_header "Updating Parameters"
    
    # Read current adminObjectId
    CURRENT_ADMIN=$(grep -oP "param adminObjectId = '\K[^']*" infra/main.bicepparam || echo "")
    
    if [ -z "$CURRENT_ADMIN" ] || [ "$CURRENT_ADMIN" = "" ]; then
        print_warning "Admin Object ID not set in parameters"
        echo "Setting to: $ADMIN_OBJECT_ID"
        sed -i "s/param adminObjectId = ''/param adminObjectId = '$ADMIN_OBJECT_ID'/" infra/main.bicepparam
    fi
    
    print_success "Parameters updated"
}

preview_deployment() {
    print_header "Previewing Deployment"
    
    echo "Running: azd provision --preview"
    if azd provision --preview; then
        print_success "Preview successful"
    else
        print_error "Preview failed"
        exit 1
    fi
}

deploy_infrastructure() {
    print_header "Deploying Infrastructure"
    
    echo "Running: azd provision"
    if azd provision; then
        print_success "Infrastructure deployed successfully"
    else
        print_error "Deployment failed"
        exit 1
    fi
}

show_deployment_info() {
    print_header "Deployment Summary"
    
    # Get resource group name (this is tricky, we need to find it from the deployment)
    RESOURCE_GROUP=$(az group list --query "[].name" -o tsv | grep "rg-secure-db" | head -1)
    
    if [ -z "$RESOURCE_GROUP" ]; then
        print_warning "Could not find resource group"
        return
    fi
    
    print_success "Resource Group: $RESOURCE_GROUP"
    
    # List key resources
    print_header "Deployed Resources"
    
    # Databricks
    DBWS=$(az databricks workspace list -g "$RESOURCE_GROUP" --query "[0].name" -o tsv 2>/dev/null || echo "Not found")
    [ "$DBWS" != "Not found" ] && print_success "Databricks Workspace: $DBWS"
    
    # Azure ML
    AML=$(az ml workspace list -g "$RESOURCE_GROUP" --query "[0].name" -o tsv 2>/dev/null || echo "Not found")
    [ "$AML" != "Not found" ] && print_success "Azure ML Workspace: $AML"
    
    # Storage
    STORAGE=$(az storage account list -g "$RESOURCE_GROUP" --query "[0].name" -o tsv 2>/dev/null || echo "Not found")
    [ "$STORAGE" != "Not found" ] && print_success "Storage Account: $STORAGE"
    
    # Key Vault
    KV=$(az keyvault list -g "$RESOURCE_GROUP" --query "[0].name" -o tsv 2>/dev/null || echo "Not found")
    [ "$KV" != "Not found" ] && print_success "Key Vault: $KV"
    
    print_success "View resources at: https://portal.azure.com/#@/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/overview"
}

main() {
    print_header "Secure Databricks Azure ML Deployment"
    
    check_prerequisites
    setup_environment
    validate_bicep
    update_parameters
    preview_deployment
    
    echo ""
    read -p "Proceed with deployment? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        deploy_infrastructure
        show_deployment_info
        print_success "Deployment completed successfully!"
    else
        print_warning "Deployment cancelled"
        exit 0
    fi
}

# Run main function
main
