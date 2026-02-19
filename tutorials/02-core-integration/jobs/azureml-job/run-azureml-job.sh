#!/bin/bash
# Bash script to submit Azure ML job for KeyVault integration test
# Usage: ./run-azureml-job.sh --subscription-id "xxx" --resource-group "xxx" --workspace-name "xxx" --key-vault-name "xxx"

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
DATABRICKS_SECRET_SCOPE="azureml-kv-scope"
COMPUTE_CLUSTER="cpu-cluster"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --subscription-id)
            SUBSCRIPTION_ID="$2"
            shift 2
            ;;
        --resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        --workspace-name)
            WORKSPACE_NAME="$2"
            shift 2
            ;;
        --key-vault-name)
            KEY_VAULT_NAME="$2"
            shift 2
            ;;
        --databricks-secret-scope)
            DATABRICKS_SECRET_SCOPE="$2"
            shift 2
            ;;
        --compute-cluster)
            COMPUTE_CLUSTER="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Unknown parameter: $1${NC}"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$SUBSCRIPTION_ID" || -z "$RESOURCE_GROUP" || -z "$WORKSPACE_NAME" || -z "$KEY_VAULT_NAME" ]]; then
    echo -e "${RED}Error: Missing required parameters${NC}"
    echo "Usage: $0 --subscription-id <id> --resource-group <rg> --workspace-name <name> --key-vault-name <name>"
    exit 1
fi

echo -e "${CYAN}🚀 Submitting AzureML KeyVault Integration Test Job${NC}"
echo "================================================================================"

# Validate Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI not found. Install from: https://aka.ms/installazurecliwindows${NC}"
    exit 1
fi

AZ_VERSION=$(az version --query '\"azure-cli\"' -o tsv)
echo -e "${GREEN}✅ Azure CLI version: $AZ_VERSION${NC}"

# Validate Azure ML extension
if ! az extension show --name ml &> /dev/null; then
    echo -e "${YELLOW}⚠️  Azure ML extension not found. Installing...${NC}"
    az extension add --name ml --yes
fi

ML_EXT_VERSION=$(az extension show --name ml --query version -o tsv)
echo -e "${GREEN}✅ Azure ML extension version: $ML_EXT_VERSION${NC}"

# Set Azure subscription
echo -e "\n${CYAN}📍 Setting subscription to: $SUBSCRIPTION_ID${NC}"
az account set --subscription "$SUBSCRIPTION_ID"

# Verify compute cluster exists
echo -e "\n${CYAN}🔍 Checking compute cluster: $COMPUTE_CLUSTER${NC}"
if ! az ml compute show --name "$COMPUTE_CLUSTER" --workspace-name "$WORKSPACE_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "${YELLOW}⚠️  Compute cluster '$COMPUTE_CLUSTER' not found. Creating...${NC}"
    
    # Create CPU compute cluster
    az ml compute create \
        --name "$COMPUTE_CLUSTER" \
        --type amlcompute \
        --size Standard_DS3_v2 \
        --min-instances 0 \
        --max-instances 4 \
        --idle-time-before-scale-down 120 \
        --workspace-name "$WORKSPACE_NAME" \
        --resource-group "$RESOURCE_GROUP"
    
    echo -e "${GREEN}✅ Compute cluster created${NC}"
else
    echo -e "${GREEN}✅ Compute cluster exists${NC}"
fi

# Update job YAML with compute cluster name
sed -i.bak "s/compute: azureml:cpu-cluster/compute: azureml:$COMPUTE_CLUSTER/g" azureml-job.yml

# Submit job
echo -e "\n${CYAN}🎯 Submitting job to Azure ML...${NC}"
echo "   Workspace: $WORKSPACE_NAME"
echo "   Resource Group: $RESOURCE_GROUP"
echo "   Compute: $COMPUTE_CLUSTER"
echo ""

JOB_OUTPUT=$(az ml job create \
    --file azureml-job.yml \
    --workspace-name "$WORKSPACE_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --set inputs.subscription_id="$SUBSCRIPTION_ID" \
    --set inputs.resource_group="$RESOURCE_GROUP" \
    --set inputs.workspace_name="$WORKSPACE_NAME" \
    --set inputs.key_vault_name="$KEY_VAULT_NAME" \
    --set inputs.databricks_secret_scope="$DATABRICKS_SECRET_SCOPE" \
    --output json)

if [ $? -eq 0 ]; then
    JOB_NAME=$(echo "$JOB_OUTPUT" | jq -r '.name')
    JOB_ID=$(echo "$JOB_OUTPUT" | jq -r '.id')
    JOB_STATUS=$(echo "$JOB_OUTPUT" | jq -r '.status')
    STUDIO_URL=$(echo "$JOB_OUTPUT" | jq -r '.services.Studio.endpoint')
    
    echo -e "${GREEN}✅ Job submitted successfully!${NC}"
    echo ""
    echo -e "${CYAN}Job Details:${NC}"
    echo -e "  Job Name: ${NC}$JOB_NAME"
    echo -e "  Job ID: ${NC}$JOB_ID"
    echo -e "  Status: ${YELLOW}$JOB_STATUS${NC}"
    echo -e "  Studio URL: ${BLUE}$STUDIO_URL${NC}"
    echo ""
    echo -e "${CYAN}🌐 Open in Azure ML Studio:${NC}"
    echo -e "   ${BLUE}$STUDIO_URL${NC}"
    echo ""
    echo -e "${CYAN}📊 Monitor job status:${NC}"
    echo -e "   az ml job show --name $JOB_NAME --workspace-name $WORKSPACE_NAME --resource-group $RESOURCE_GROUP"
    echo ""
    echo -e "${CYAN}📥 Stream job logs:${NC}"
    echo -e "   az ml job stream --name $JOB_NAME --workspace-name $WORKSPACE_NAME --resource-group $RESOURCE_GROUP"
    
    # Ask if user wants to stream logs
    read -p "$(echo -e ${CYAN}Would you like to stream the job logs now? \(y/n\): ${NC})" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "\n${CYAN}📡 Streaming job logs...${NC}"
        az ml job stream --name "$JOB_NAME" --workspace-name "$WORKSPACE_NAME" --resource-group "$RESOURCE_GROUP"
    fi
else
    echo -e "${RED}❌ Job submission failed${NC}"
    exit 1
fi
