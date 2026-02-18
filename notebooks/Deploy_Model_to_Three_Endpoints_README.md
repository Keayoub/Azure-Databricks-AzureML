# Deploy One Model to Three AzureML Endpoint Types

## Overview

This notebook demonstrates how to deploy the same machine learning model to three different Azure ML endpoint types using Azure ML SDK v2:

- **🅰️ Managed Online Endpoint** - Real-time inference with fully managed infrastructure
- **🅱️ Serverless Endpoint** - Pay-per-use serverless inference (or serverless-like pattern)
- **🅾️ Batch Endpoint** - Large-scale batch scoring for asynchronous workloads

The notebook also shows how to consume each endpoint type from Databricks.

## Prerequisites

### Azure Resources

- Azure subscription with sufficient permissions
- Azure ML workspace (configured and accessible)
- Appropriate RBAC roles:
  - `AzureML Data Scientist` or `Contributor` on the workspace
  - Permissions to create endpoints and deployments

### Databricks Environment

- Databricks workspace with Runtime 13.0 or higher
- Cluster with internet access for package installation
- Authentication configured (Service Principal, Managed Identity, or Azure CLI)

### Python Packages

The notebook installs these automatically:
- `azure-ai-ml` - Azure ML SDK v2
- `azure-identity` - Azure authentication
- `requests` - HTTP client for endpoint consumption
- `scikit-learn` - For the example model

## Notebook Structure

### SECTION 1: Install Dependencies
Installs required Azure ML SDK v2 packages and dependencies.

### SECTION 2: Configure AzureML Client
Sets up authentication and creates an `MLClient` instance to interact with Azure ML workspace.

**Placeholders to replace:**
- `<SUBSCRIPTION_ID>` - Your Azure subscription ID
- `<RESOURCE_GROUP>` - Your Azure resource group name
- `<AML_WORKSPACE>` - Your Azure ML workspace name

### SECTION 3: Load or Create a Simple Model
Creates a scikit-learn Logistic Regression model using the Iris dataset:
- Trains the model
- Saves as `model.pkl`
- Creates a scoring script (`score.py`)
- Registers the model in Azure ML

### SECTION 4: Deploy to Managed Online Endpoint (A)
Deploys the model to a Managed Online Endpoint:
1. Creates `ManagedOnlineEndpoint` with key-based authentication
2. Creates `ManagedOnlineDeployment` with VM instances
3. Allocates 100% traffic to the deployment
4. Retrieves scoring URI and authentication key

**Placeholder:** `<MANAGED_ENDPOINT_NAME>`

### SECTION 5: Deploy to Serverless Endpoint (B)
Demonstrates serverless deployment patterns:
- Explains `ServerlessEndpoint` for Azure ML catalog models
- Creates a serverless-like Managed Online Endpoint as an alternative
- Configures deployment for cost-effective serverless behavior

**Placeholder:** `<SERVERLESS_ENDPOINT_NAME>`

### SECTION 6: Deploy to Batch Endpoint (C)
Deploys the model to a Batch Endpoint:
1. Creates `BatchEndpoint`
2. Creates `BatchDeployment` with compute cluster
3. Prepares batch input data
4. Invokes batch scoring job
5. Monitors job status
6. Downloads results

**Placeholder:** `<BATCH_ENDPOINT_NAME>`

### SECTION 7: Consume Each Endpoint
Shows how to call each endpoint from Databricks:

#### A. Managed Online Endpoint
- REST API call with Bearer token authentication
- Single record and batch predictions
- JSON payload format

#### B. Serverless-like Online Endpoint
- Same REST API pattern as Managed
- Demonstrates identical consumption interface

#### C. Batch Endpoint
- Job-based invocation using `MLClient`
- Status monitoring with polling
- Result retrieval from datastore

## Configuration Guide

### Step 1: Set Your Azure Values

Replace these placeholders in **SECTION 2**:

```python
subscription_id = "<SUBSCRIPTION_ID>"        # e.g., "12345678-1234-1234-1234-123456789abc"
resource_group = "<RESOURCE_GROUP>"          # e.g., "my-resource-group"
workspace_name = "<AML_WORKSPACE>"           # e.g., "my-azureml-workspace"
```

### Step 2: Set Endpoint Names

Replace these placeholders throughout the notebook:

```python
managed_endpoint_name = "<MANAGED_ENDPOINT_NAME>"          # e.g., "iris-managed-endpoint"
serverless_like_endpoint_name = "<SERVERLESS_ENDPOINT_NAME>"  # e.g., "iris-serverless-endpoint"
batch_endpoint_name = "<BATCH_ENDPOINT_NAME>"              # e.g., "iris-batch-endpoint"
```

**Important:** Endpoint names must be:
- Unique within the workspace
- 3-32 characters long
- Lowercase letters, numbers, and hyphens only
- Start with a letter

### Step 3: Configure Batch Compute (SECTION 6)

Replace the compute cluster name:

```python
compute="cpu-cluster"  # Replace with your compute cluster name
```

**Note:** You need a pre-existing compute cluster for batch deployments.

### Step 4: Set Consumption Credentials (SECTION 7)

After deploying endpoints, copy the scoring URIs and keys:

```python
# From SECTION 4.4
managed_endpoint_url = "<MANAGED_ENDPOINT_URL>"
managed_api_key = "<PRIMARY_KEY>"

# From SECTION 5.3
serverless_endpoint_url = "<SERVERLESS_ENDPOINT_URL>"
serverless_api_key = "<PRIMARY_KEY>"

# From SECTION 6
batch_endpoint_name = "<BATCH_ENDPOINT_NAME>"
```

## Security Best Practices

### ⚠️ Never Hardcode Secrets

Instead of hardcoding credentials, use:

#### Option 1: Databricks Secrets
```python
import dbutils

subscription_id = dbutils.secrets.get(scope="azure", key="subscription-id")
managed_api_key = dbutils.secrets.get(scope="azure", key="managed-endpoint-key")
```

#### Option 2: Environment Variables
```python
import os

subscription_id = os.getenv("AZURE_SUBSCRIPTION_ID")
resource_group = os.getenv("AZURE_RESOURCE_GROUP")
```

#### Option 3: Azure Key Vault
```python
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential

credential = DefaultAzureCredential()
vault_url = "https://<your-vault>.vault.azure.net/"
client = SecretClient(vault_url=vault_url, credential=credential)

api_key = client.get_secret("endpoint-api-key").value
```

### Authentication Methods

The notebook uses `DefaultAzureCredential`, which tries:
1. Environment variables (Service Principal)
2. Managed Identity
3. Azure CLI credentials
4. Interactive browser (disabled in this notebook)

For production Databricks:
- Use **Managed Identity** (recommended)
- Or **Service Principal** with credentials in Databricks Secrets

## Execution Time

Approximate execution times:

| Section | Time | Notes |
|---------|------|-------|
| Sections 1-3 | 2-3 minutes | Package installation and model training |
| Section 4 (Managed) | 10-15 minutes | Endpoint + deployment creation |
| Section 5 (Serverless) | 10-15 minutes | Endpoint + deployment creation |
| Section 6 (Batch) | 10-15 minutes | Endpoint + deployment creation |
| Section 7 | < 1 minute | Consumption examples |
| **Total** | **~35-50 minutes** | For all three endpoints |

**Tip:** Sections 4, 5, and 6 can be run in parallel using separate notebooks to save time.

## Cost Considerations

### Managed Online Endpoints
- **Charged:** Per VM hour (even when idle)
- **Cost:** Depends on instance type (e.g., Standard_DS2_v2)
- **Tip:** Scale down or delete when not in use

### Serverless Endpoints
- **Charged:** Per request (pay-per-use)
- **Cost:** No idle charges, but per-request fee
- **Tip:** Ideal for unpredictable workloads

### Batch Endpoints
- **Charged:** Per compute hour during job execution
- **Cost:** Only when jobs are running
- **Tip:** Most cost-effective for large-scale scoring

## Troubleshooting

### Authentication Errors

**Error:** `DefaultAzureCredential failed to retrieve a token`

**Solution:**
- Ensure Managed Identity is enabled on Databricks cluster
- Or configure Service Principal credentials:
  ```bash
  export AZURE_CLIENT_ID="<client-id>"
  export AZURE_CLIENT_SECRET="<client-secret>"
  export AZURE_TENANT_ID="<tenant-id>"
  ```

### Endpoint Creation Failures

**Error:** `Endpoint name already exists`

**Solution:** Choose a different endpoint name or delete the existing endpoint:
```python
ml_client.online_endpoints.begin_delete(name="endpoint-name").result()
```

**Error:** `Insufficient quota for instance type`

**Solution:** 
- Request quota increase in Azure portal
- Or use a smaller instance type: `Standard_DS1_v2`, `Standard_F2s_v2`

### Deployment Timeout

**Error:** Deployment takes longer than 15 minutes

**Solution:** This is normal for first deployment. Check status:
```python
deployment = ml_client.online_deployments.get(
    name="blue",
    endpoint_name="endpoint-name"
)
print(deployment.provisioning_state)
```

### Batch Job Failures

**Error:** `Compute cluster not found`

**Solution:** Create a compute cluster first:
```python
from azure.ai.ml.entities import AmlCompute

compute = AmlCompute(
    name="cpu-cluster",
    size="Standard_DS3_v2",
    min_instances=0,
    max_instances=4
)
ml_client.compute.begin_create_or_update(compute).result()
```

## Cleanup

To avoid ongoing charges, delete endpoints after testing:

```python
# Delete Managed Online Endpoint
ml_client.online_endpoints.begin_delete(name="<MANAGED_ENDPOINT_NAME>").result()

# Delete Serverless-like Endpoint
ml_client.online_endpoints.begin_delete(name="<SERVERLESS_ENDPOINT_NAME>").result()

# Delete Batch Endpoint
ml_client.batch_endpoints.begin_delete(name="<BATCH_ENDPOINT_NAME>").result()
```

## Additional Resources

### Documentation
- [Azure ML SDK v2 Documentation](https://learn.microsoft.com/en-us/python/api/overview/azure/ai-ml-readme)
- [Managed Online Endpoints](https://learn.microsoft.com/en-us/azure/machine-learning/how-to-deploy-online-endpoints)
- [Serverless Endpoints](https://learn.microsoft.com/en-us/azure/machine-learning/how-to-deploy-models-serverless)
- [Batch Endpoints](https://learn.microsoft.com/en-us/azure/machine-learning/how-to-use-batch-endpoint)

### Related Notebooks in This Repository
- `05_Real_Time_Inference.ipynb` - Real-time inference patterns
- `03_Batch_Prediction_Scoring.ipynb` - Batch scoring workflows
- `04_MLOps_Orchestration.ipynb` - MLOps automation

### Azure ML Model Catalog
For serverless endpoints with catalog models:
- [Browse Azure ML Model Catalog](https://ml.azure.com/model/catalog)
- Includes pre-trained models: GPT, BERT, Llama, etc.
- Deployed directly with `ServerlessEndpoint`

## Support

For issues or questions:
1. Check [Azure ML documentation](https://learn.microsoft.com/en-us/azure/machine-learning/)
2. Review [Azure ML GitHub issues](https://github.com/Azure/azure-sdk-for-python/issues)
3. Post on [Microsoft Q&A](https://learn.microsoft.com/en-us/answers/tags/438/azure-machine-learning)

## License

This notebook is part of the Azure-Databricks-AzureML integration repository.
See repository root for license information.
