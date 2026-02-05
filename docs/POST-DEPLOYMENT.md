# Post-Deployment Configuration Guide

This guide provides step-by-step instructions for configuring your Azure Databricks, Azure ML, and AI Foundry deployment after the infrastructure has been deployed using the Bicep templates.

## Table of Contents

1. [Unity Catalog Setup](#unity-catalog-setup)
2. [Delta Sharing Configuration](#delta-sharing-configuration)
3. [Azure ML Integration](#azure-ml-integration)
4. [AI Foundry Hub Configuration](#ai-foundry-hub-configuration)
5. [AKS Model Serving (Optional)](#aks-model-serving-optional)
6. [Security Verification](#security-verification)

---

## Unity Catalog Setup

### Prerequisites

- Databricks workspace deployed and accessible
- Storage account with ADLS Gen2 enabled
- Databricks CLI installed: `pip install databricks-cli`

### Step 1: Get Databricks Workspace Information

```bash
# Get your resource group name (pattern: rg-{env}-{project}-databricks)
RESOURCE_GROUP=$(az group list --query "[].name" -o tsv | grep "databricks")

# Get Databricks workspace URL
WORKSPACE_URL=$(az databricks workspace show \
  --resource-group $RESOURCE_GROUP \
  --name $(az databricks workspace list -g $RESOURCE_GROUP --query "[0].name" -o tsv) \
  --query workspaceUrl -o tsv)

echo "Workspace URL: $WORKSPACE_URL"
```

### Step 2: Create and Share Personal Access Token

In Databricks UI:

1. Go to **Settings** → **User Settings** → **Access Tokens**
2. Click **Generate new token**
3. Set expiration (e.g., 90 days)
4. Click **Generate**
5. Copy token (you won't see it again)

### Step 3: Configure Databricks CLI

```bash
# Set environment variables
export DATABRICKS_HOST=$WORKSPACE_URL
export DATABRICKS_TOKEN=<your-pat-token>

# Test connection
databricks workspace list
```

### Step 4: Get Storage Account Information

```bash
# Get storage account details
STORAGE_ACCOUNT=$(az storage account list -g $RESOURCE_GROUP --query "[0].name" -o tsv)
STORAGE_ACCOUNT_KEY=$(az storage account keys list -g $RESOURCE_GROUP -n $STORAGE_ACCOUNT --query "[0].value" -o tsv)
STORAGE_URL="abfss://unity-catalog@${STORAGE_ACCOUNT}.dfs.core.windows.net/"

echo "Storage URL: $STORAGE_URL"
```

### Step 5: Create Metastore

```bash
# Create Unity Catalog metastore
databricks unity-catalog metastores create \
  --name main \
  --storage-root "$STORAGE_URL" \
  --region us-east-1 \  # Match your deployment region
  --comment "Main metastore for Unity Catalog"

# Get metastore ID
METASTORE_ID=$(databricks unity-catalog metastores list --output json | jq -r '.metastores[0].metastore_id')
echo "Metastore ID: $METASTORE_ID"
```

### Step 6: Assign Metastore to Workspace

```bash
# Get workspace ID
WORKSPACE_ID=$(az databricks workspace show \
  --resource-group $RESOURCE_GROUP \
  --name $(az databricks workspace list -g $RESOURCE_GROUP --query "[0].name" -o tsv) \
  --query workspaceId -o tsv)

# Assign metastore to workspace
databricks unity-catalog metastores assign \
  --workspace-id $WORKSPACE_ID \
  --metastore-id $METASTORE_ID

echo "Metastore assigned to workspace $WORKSPACE_ID"
```

### Step 7: Create Default Catalog

```bash
# Create external catalog for existing data
databricks unity-catalog catalogs create \
  --name default_catalog \
  --comment "Default catalog for managed tables"

# Or create managed catalog
databricks unity-catalog catalogs create \
  --name managed_catalog \
  --storage-root "abfss://managed@${STORAGE_ACCOUNT}.dfs.core.windows.net/" \
  --comment "Managed catalog with workspace storage"
```

### Step 8: Create External Location

For accessing data stored in your storage account:

```bash
# Create external location
databricks unity-catalog external-locations create \
  --name prod_data_location \
  --url "abfss://data@${STORAGE_ACCOUNT}.dfs.core.windows.net/" \
  --credential-name unity-catalog-credential \
  --comment "Production data location"
```

### Step 9: Create Storage Credential

```bash
# Create storage credential (using managed identity)
databricks unity-catalog storage-credentials create \
  --name unity-catalog-credential \
  --storage-credential-info "{
    'azure_service_principal': {
      'tenant_id': '$(az account show --query tenantId -o tsv)',
      'application_id': '<service-principal-id>',
      'client_secret': '<service-principal-secret>'
    }
  }"

# Or use managed identity (preferred)
databricks unity-catalog storage-credentials create \
  --name managed-identity-credential \
  --managed-identity-credential "{}"
```

### Step 10: Verify Unity Catalog

In Databricks notebook:

```python
# List catalogs
spark.sql("SHOW CATALOGS")

# Create test schema
spark.sql("CREATE SCHEMA IF NOT EXISTS default_catalog.test_schema")

# Create test table
spark.sql("""
CREATE TABLE IF NOT EXISTS default_catalog.test_schema.sample_table (
  id INT,
  name STRING,
  value DOUBLE
)
USING DELTA
""")

# Query table
spark.sql("SELECT * FROM default_catalog.test_schema.sample_table")
```

---

## Delta Sharing Configuration

### Step 1: Enable Delta Sharing on Metastore

```bash
# Enable Delta Sharing
databricks unity-catalog delta-sharing enable-sharing \
  --metastore-id $METASTORE_ID
```

### Step 2: Create Share

```bash
# Create a share
databricks unity-catalog shares create \
  --name customer_analytics_share \
  --comment "Share for customer analytics data"

# Get share ID
SHARE_ID=$(databricks unity-catalog shares list --output json | jq -r '.shares[0].share_id')
```

### Step 3: Add Tables to Share

```bash
# Add table to share (must exist in Unity Catalog)
databricks unity-catalog shares objects add \
  --share-name customer_analytics_share \
  --object-name "default_catalog.test_schema.sample_table" \
  --object-type TABLE

# Verify tables in share
databricks unity-catalog shares objects list \
  --share-name customer_analytics_share
```

### Step 4: Create Recipients (for Databricks-to-Databricks Sharing)

```bash
# Create recipient for another Databricks workspace
databricks unity-catalog recipients create \
  --name external-partner \
  --recipient-type ORGANIZATION \
  --comment "External partner organization"

# Get sharing identifier from external workspace
# (They provide this via secure channel)
EXTERNAL_SHARING_ID="<shared-identifier-from-external-ws>"

# Verify recipient
databricks unity-catalog recipients list
```

### Step 5: Grant Access

```bash
# Grant recipient access to share
databricks unity-catalog shares permissions grant \
  --share-name customer_analytics_share \
  --recipient-name external-partner \
  --permission-level READ_ONLY

# Verify permissions
databricks unity-catalog shares permissions list \
  --share-name customer_analytics_share
```

### Step 6: Monitor Delta Sharing

```python
# In Databricks notebook - view sharing activity
spark.sql("""
SELECT * FROM system.access.table_lineage
WHERE table_name = 'sample_table'
""")

# View audit logs
spark.sql("""
SELECT * FROM system.access.audit
WHERE action_type = 'SHARE_ACCESS'
ORDER BY timestamp DESC
LIMIT 100
""")
```

---

## Azure ML Integration

### Step 1: Configure ML Workspace Connection

```bash
# Get Azure ML workspace details
ML_WORKSPACE=$(az ml workspace list -g $RESOURCE_GROUP --query "[0].name" -o tsv)
ML_WORKSPACE_ID=$(az ml workspace show -g $RESOURCE_GROUP -n $ML_WORKSPACE --query id -o tsv)

echo "Azure ML Workspace: $ML_WORKSPACE"
```

### Step 2: Create Databricks Linked Service in Azure ML

```bash
# Create linked compute resource in Azure ML
az ml compute create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $ML_WORKSPACE \
  --name databricks-compute \
  --type Databricks \
  --databricks-workspace-url "$WORKSPACE_URL" \
  --databricks-import-query "SELECT * FROM \`system\`.access.table_lineage" \
  --shared-user-authentication \
  --databricks-msi-auth
```

### Step 3: Create Azure ML Compute Cluster

```bash
# Create compute instance for development
az ml compute create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $ML_WORKSPACE \
  --name dev-cpu-cluster \
  --type AmlCompute \
  --min-instances 0 \
  --max-instances 10 \
  --size Standard_DS3_v2
```

### Step 4: Configure Model Registry

```python
# In Azure ML SDK (Python)
from azure.ai.ml import MLClient
from azure.ai.ml.entities import Model
from azure.identity import DefaultAzureCredential

# Connect to Azure ML workspace
ml_client = MLClient(
    credential=DefaultAzureCredential(),
    subscription_id="<subscription-id>",
    resource_group_name="<resource-group>",
    workspace_name="<workspace-name>"
)

# Register model from Databricks
model = Model(
    path="dbfs:/models/my-model/",
    name="my-model",
    description="Model trained on Databricks with Delta Lake data",
    type="custom_model",
    stage="Production"
)

ml_client.models.create_or_update(model)
```

---

## AI Foundry Hub Configuration

### Step 1: Access AI Foundry Hub

```bash
# Get AI Foundry hub details
AI_HUB=$(az ml workspace list -g $RESOURCE_GROUP --query "[?contains(name, 'aihub')] | [0].name" -o tsv)

echo "AI Foundry Hub: $AI_HUB"
```

### Step 2: Create AI Projects

```bash
# Create AI project linked to hub
az ml workspace create \
  --name customer-insights-project \
  --resource-group $RESOURCE_GROUP \
  --kind project \
  --hub-id "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.MachineLearningServices/workspaces/$AI_HUB" \
  --display-name "Customer Insights AI Project"
```

### Step 3: Configure AI Services Connection

```python
# In AI Foundry (Azure ML SDK for AI)
from azure.ai.ml.entities import AzureOpenAIConnection

# Create Azure OpenAI connection
connection = AzureOpenAIConnection(
    name="openai-connection",
    endpoint="https://<openai-resource>.openai.azure.com/",
    api_key="<api-key>"  # Consider using Key Vault
)
```

---

## AKS Model Serving (Optional)

### Step 1: Get AKS Cluster Credentials

```bash
# Get AKS cluster name
AKS_CLUSTER=$(az aks list -g $RESOURCE_GROUP --query "[0].name" -o tsv)

# Get kubeconfig
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER \
  --admin

# Verify connection
kubectl get nodes
```

### Step 2: Deploy Azure ML Inference

```bash
# Install Azure ML CLI extension
az extension add --name machine-learning

# Deploy model to AKS
az ml online-deployment create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $ML_WORKSPACE \
  --endpoint-name prediction-endpoint \
  --deployment-config-path deployment.yml \
  --deployment-name blue
```

### Step 3: Create Kubernetes Secret for Container Registry

```bash
# Create image pull secret
kubectl create secret docker-registry acr-secret \
  --docker-server=<acr-name>.azurecr.io \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=admin@example.com \
  -n azureml
```

### Step 4: Monitor Deployment

```bash
# Check deployment status
kubectl get pods -n azureml

# View logs
kubectl logs -n azureml deployment/prediction-endpoint

# Port forward for testing
kubectl port-forward -n azureml svc/prediction-endpoint 8000:8000
```

---

## Security Verification

### Step 1: Verify Network Isolation

```bash
# Check private endpoints
az network private-endpoint list -g $RESOURCE_GROUP -o table

# Verify no public IPs
az vm public-ip-address list -g $RESOURCE_GROUP -o table

# Check NSG rules
az network nsg rule list --nsg-name nsg-databricks-public -g $RESOURCE_GROUP -o table
```

### Step 2: Verify Private DNS Resolution

```bash
# From AKS pod or VM
nslookup <storage-account>.blob.core.windows.net
# Should resolve to private IP (10.x.x.x), not public

# Test private endpoint connectivity
curl -I https://<storage-account>.blob.core.windows.net
```

### Step 3: Audit Access

```bash
# Check Key Vault access logs
az keyvault key list-deleted \
  --vault-name <key-vault-name> \
  -g $RESOURCE_GROUP

# Check storage access logs
az storage logging update \
  --account-name $STORAGE_ACCOUNT \
  --account-key $STORAGE_ACCOUNT_KEY \
  --services b \
  --log rwd \
  --retention 7
```

### Step 4: Monitor Compliance

```bash
# Check Azure Policy compliance
az policy state list -g $RESOURCE_GROUP --query "[].complianceState" | sort | uniq -c

# View audit logs
az monitor activity-log list \
  --resource-group $RESOURCE_GROUP \
  --query "[].operationName" | sort | uniq
```

---

## Troubleshooting

### Databricks Cannot Connect to Storage

**Symptom**: "PERMISSION_DENIED" errors when accessing ADLS Gen2

**Solution**:
1. Verify managed identity has "Storage Blob Data Contributor" role
2. Check storage account firewall rules
3. Ensure private endpoint is configured correctly

```bash
az role assignment list \
  --resource-group $RESOURCE_GROUP \
  --scope <storage-account-id>
```

### Unity Catalog Configuration Fails

**Symptom**: "RESOURCE_NOT_FOUND" when accessing metastore

**Solution**:
1. Verify metastore storage location exists
2. Check storage credential permissions
3. Ensure workspace is assigned to metastore

```bash
databricks unity-catalog metastores list
databricks unity-catalog catalogs list
```

### Azure ML Compute Cannot Access Databricks

**Symptom**: Connection timeout to Databricks

**Solution**:
1. Verify network routes in subnet
2. Check NSG rules allow outbound to Databricks
3. Ensure private endpoints are configured

```bash
az network route-table list -g $RESOURCE_GROUP -o table
```

---

For additional support, refer to:
- [Databricks Documentation](https://docs.databricks.com/)
- [Azure ML Documentation](https://learn.microsoft.com/en-us/azure/machine-learning/)
- [Azure Databricks Security Best Practices](https://learn.microsoft.com/en-us/azure/databricks/security/)
