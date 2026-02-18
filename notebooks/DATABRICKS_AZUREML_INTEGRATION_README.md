# Databricks + Azure Machine Learning Integration

This directory contains comprehensive examples for integrating Azure Databricks with Azure Machine Learning using SDK v2.

## 📁 Files

### 1. `Complete_Databricks_AzureML_Integration.ipynb`

**Purpose**: Complete Databricks notebook demonstrating full integration with Azure Machine Learning.

**Sections**:
1. **Install Dependencies** - Install azure-ai-ml and azure-identity packages
2. **Configure AzureML Client** - Set up authentication with DefaultAzureCredential
3. **Submit Command Jobs** - Submit training jobs to AzureML compute
4. **Register Models** - Register models from DBFS to AzureML
5. **Trigger AutoML Jobs** - Launch AutoML classification experiments
6. **Log Metrics** - Track experiments and metrics in AzureML
7. **Databricks Pipeline Integration** - Create pipelines that call Databricks jobs
8. **Complete Example** - End-to-end workflow demonstration

**Usage**:
- Open in Azure Databricks
- Replace all `<PLACEHOLDER>` values with your actual configuration
- Run cells sequentially or select specific sections

### 2. `pipeline_databricks.py`

**Purpose**: Standalone Python script to create and submit AzureML pipelines that trigger Databricks jobs.

**Features**:
- Authenticates to AzureML using DefaultAzureCredential
- Creates a pipeline component that triggers Databricks jobs via REST API
- Waits for Databricks job completion
- Provides detailed status updates

**Usage**:
```bash
# 1. Update placeholders in the script
# 2. Run the script
python pipeline_databricks.py
```

**Requirements**:
- Azure Machine Learning workspace
- Azure Databricks workspace with existing job
- Compute cluster in AzureML
- Databricks access token (store in Azure Key Vault)

### 3. `src/train.py`

**Purpose**: Example training script for AzureML command jobs.

**Features**:
- Trains a Random Forest classifier on Iris dataset
- Logs parameters and metrics to MLflow
- Saves model artifacts to AzureML
- Command-line argument parsing

**Usage**:
```bash
python train.py --epochs 10 --learning-rate 0.01 --n-estimators 100
```

## 🚀 Quick Start

### Option 1: Databricks Notebook (Recommended for Interactive Use)

1. **Upload notebook to Databricks**:
   - Navigate to your Databricks workspace
   - Import `Complete_Databricks_AzureML_Integration.ipynb`

2. **Configure placeholders**:
   ```python
   subscription_id = "<SUBSCRIPTION_ID>"
   resource_group = "<RESOURCE_GROUP>"
   workspace_name = "<AML_WORKSPACE>"
   ```

3. **Run the notebook**:
   - Execute cells sequentially
   - Monitor jobs in AzureML Studio

### Option 2: Pipeline Script (Recommended for Automation)

1. **Update configuration** in `pipeline_databricks.py`:
   ```python
   SUBSCRIPTION_ID = "<SUBSCRIPTION_ID>"
   RESOURCE_GROUP = "<RESOURCE_GROUP>"
   AML_WORKSPACE = "<AML_WORKSPACE>"
   COMPUTE_CLUSTER_NAME = "<COMPUTE_CLUSTER_NAME>"
   DATABRICKS_WORKSPACE_URL = "<DATABRICKSWORKSPACEURL>"
   DATABRICKS_JOB_ID = "<DATABRICKSJOBID>"
   ```

2. **Install dependencies**:
   ```bash
   pip install azure-ai-ml azure-identity
   ```

3. **Run the script**:
   ```bash
   python pipeline_databricks.py
   ```

## 📋 Prerequisites

### Azure Resources
- ✅ Azure subscription with appropriate permissions
- ✅ Azure Machine Learning workspace
- ✅ Azure Databricks workspace
- ✅ AzureML compute cluster
- ✅ Databricks job (for pipeline integration)

### Authentication
Choose one of the following:

1. **Managed Identity** (Recommended for production):
   - Configure managed identity on compute/VM
   - Assign appropriate roles to identity

2. **Service Principal**:
   ```bash
   export AZURE_CLIENT_ID="<client-id>"
   export AZURE_TENANT_ID="<tenant-id>"
   export AZURE_CLIENT_SECRET="<client-secret>"
   ```

3. **Azure CLI**:
   ```bash
   az login
   ```

### Python Packages
```bash
pip install azure-ai-ml azure-identity mlflow scikit-learn
```

## 🔒 Security Best Practices

### 1. Never Hardcode Secrets

❌ **Bad**:
```python
databricks_token = "dapi123456789..."
```

✅ **Good**:
```python
# Use Azure Key Vault
from azure.keyvault.secrets import SecretClient
secret_client = SecretClient(vault_url="https://my-vault.vault.azure.net/", credential=credential)
databricks_token = secret_client.get_secret("databricks-token").value
```

### 2. Use Databricks Secrets

In Databricks notebooks:
```python
databricks_token = dbutils.secrets.get(scope="my-scope", key="databricks-token")
```

### 3. Use Environment Variables

For local development:
```bash
export DATABRICKS_TOKEN="<token>"
```

```python
import os
databricks_token = os.environ.get("DATABRICKS_TOKEN")
```

## 📊 What Gets Created

When you run the notebook or pipeline script:

### In AzureML
- ✅ **Experiments**: Organized tracking of runs and metrics
- ✅ **Jobs**: Training and pipeline executions
- ✅ **Models**: Registered models with versions
- ✅ **Metrics**: Performance tracking and comparison
- ✅ **Pipelines**: Orchestrated workflows

### In Databricks
- ✅ **Job Triggers**: Initiated from AzureML pipelines
- ✅ **Model Files**: Registered from DBFS to AzureML
- ✅ **Integration**: Seamless workflow between services

## 🔍 Monitoring

### AzureML Studio
View all activities at:
```
https://ml.azure.com
```

Navigate to:
- **Jobs**: Monitor training and pipeline runs
- **Models**: View registered models and versions
- **Experiments**: Track metrics and comparisons
- **Compute**: Monitor cluster utilization

### Databricks
Monitor triggered jobs at:
```
https://<workspace-url>/#jobs
```

## 📝 Configuration Reference

### Required Placeholders

| Placeholder | Description | Example |
|------------|-------------|---------|
| `<SUBSCRIPTION_ID>` | Azure subscription ID | `12345678-1234-1234-1234-123456789012` |
| `<RESOURCE_GROUP>` | Azure resource group name | `my-ml-resources` |
| `<AML_WORKSPACE>` | AzureML workspace name | `my-ml-workspace` |
| `<COMPUTE_CLUSTER_NAME>` | AzureML compute cluster | `cpu-cluster` |
| `<DATABRICKSWORKSPACEURL>` | Databricks workspace URL | `https://adb-123456.azuredatabricks.net` |
| `<DATABRICKSJOBID>` | Databricks job ID | `123456` |
| `<DATABRICKS_TOKEN>` | Databricks access token | `dapi...` (use Key Vault!) |
| `<TARGET_COLUMN>` | ML target column name | `label` |
| `<MLTABLE_PATH>` | Path to MLTable dataset | `azureml://datastores/workspaceblobstore/paths/data/` |

## 🛠️ Troubleshooting

### Authentication Issues

**Problem**: `DefaultAzureCredential failed to retrieve a token`

**Solutions**:
1. Ensure you're logged in: `az login`
2. Check environment variables are set correctly
3. Verify managed identity has appropriate roles

### Compute Not Found

**Problem**: `Compute target '<name>' not found`

**Solution**:
1. Create compute cluster in AzureML Studio
2. Update placeholder with exact cluster name

### Databricks Job Trigger Fails

**Problem**: `Failed to trigger Databricks job`

**Solutions**:
1. Verify job ID exists in Databricks
2. Check token has appropriate permissions
3. Ensure workspace URL is correct (include `https://`)

## 📚 Additional Resources

- [Azure ML SDK v2 Documentation](https://learn.microsoft.com/azure/machine-learning/how-to-configure-cli)
- [Azure Databricks Documentation](https://learn.microsoft.com/azure/databricks/)
- [MLflow on Azure ML](https://learn.microsoft.com/azure/machine-learning/how-to-use-mlflow)
- [AutoML in Azure ML](https://learn.microsoft.com/azure/machine-learning/concept-automated-ml)
- [Databricks Jobs API](https://docs.databricks.com/dev-tools/api/latest/jobs.html)

## 🤝 Contributing

When adding new examples:
1. Follow the existing code structure
2. Include comprehensive docstrings
3. Add error handling
4. Update this README
5. Test with placeholder values

## 📄 License

This project is part of the Azure-Databricks-AzureML repository. See the main repository for license information.
