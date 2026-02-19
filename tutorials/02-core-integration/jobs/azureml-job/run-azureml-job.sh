#!/bin/bash
# Bash script to submit Azure ML job for KeyVault integration test
# Usage: ./run-azureml-job.sh --subscription-id "xxx" --resource-group "xxx" --workspace-name "xxx" --key-vault-name "xxx"

set -e

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
            echo "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# Validate parameters
if [[ -z "$SUBSCRIPTION_ID" || -z "$RESOURCE_GROUP" || -z "$WORKSPACE_NAME" || -z "$KEY_VAULT_NAME" ]]; then
    echo "Error: Missing required parameters"
    echo "Usage: $0 --subscription-id <id> --resource-group <rg> --workspace-name <name> --key-vault-name <name>"
    exit 1
fi

echo ""
echo "Submitting Azure ML job..."
echo "Subscription: $SUBSCRIPTION_ID"
echo "Workspace: $WORKSPACE_NAME"
echo "Compute: $COMPUTE_CLUSTER"

# Validate Azure CLI
if ! command -v az &> /dev/null; then
    echo "Error: Azure CLI not found"
    exit 1
fi

AZ_VERSION=$(az version --query '\"azure-cli\"' -o tsv)
echo "Azure CLI version: $AZ_VERSION"

# Validate ML extension
if ! az extension show --name ml &> /dev/null; then
    echo "Installing Azure ML extension..."
    az extension add --name ml --yes
fi

ML_EXT_VERSION=$(az extension show --name ml --query version -o tsv)
echo "ML extension version: $ML_EXT_VERSION"

# Set subscription
echo ""
echo "Setting subscription..."
az account set --subscription "$SUBSCRIPTION_ID"

# Check compute cluster
echo ""
echo "Checking compute cluster..."
if ! az ml compute show --name "$COMPUTE_CLUSTER" --workspace-name "$WORKSPACE_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    echo "Creating compute cluster..."
    az ml compute create \
        --name "$COMPUTE_CLUSTER" \
        --type amlcompute \
        --size Standard_DS3_v2 \
        --min-instances 0 \
        --max-instances 4 \
        --idle-time-before-scale-down 120 \
        --workspace-name "$WORKSPACE_NAME" \
        --resource-group "$RESOURCE_GROUP"
    echo "Compute cluster created"
else
    echo "Compute cluster exists"
fi

# Submit job
echo ""
echo "Submitting job..."

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
    JOB_NAME=$(echo "$JOB_OUTPUT" | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    STUDIO_URL=$(echo "$JOB_OUTPUT" | grep -o '"endpoint"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"endpoint"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    
    echo ""
    echo "Job submitted successfully"
    echo "Job Name: $JOB_NAME"
    echo "Studio URL: $STUDIO_URL"
    
    read -p "Stream job logs? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Streaming logs..."
        az ml job stream --name "$JOB_NAME" --workspace-name "$WORKSPACE_NAME" --resource-group "$RESOURCE_GROUP"
    fi
else
    echo "Error: Job submission failed"
    exit 1
fi
