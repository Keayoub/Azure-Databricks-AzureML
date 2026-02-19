# Running AzureML_KeyVault_Integration Notebook as Azure ML Job

This guide explains how to run the `AzureML_KeyVault_Integration.ipynb` notebook as an Azure ML job using the `az ml` CLI.

## 📁 Folder Structure

```
tutorials/02-core-integration/
├── AzureML_KeyVault_Integration.ipynb  ← The notebook to execute
└── jobs/
    └── azureml-job/                     ← You are here
        ├── azureml-job.yml              ← Job definition (references ../../notebook)
        ├── conda-env.yml                ← Python environment
        ├── run-azureml-job.ps1          ← Submission script
        └── README.md                    ← This file
```

**Note**: The job runs from the parent directory (`../../`) to access the notebook.

## 📁 Files

- **azureml-job.yml** - Azure ML job definition
- **conda-env.yml** - Python environment specification
- **run-azureml-job.ps1** - PowerShell submission script (Windows)
- **run-azureml-job.sh** - Bash submission script (Linux/Mac)

## 🚀 Quick Start

### Windows (PowerShell)

```powershell
# Run from the azureml-job folder
cd tutorials/02-core-integration/jobs/azureml-job

.\run-azureml-job.ps1 `
    -SubscriptionId "your-subscription-id" `
    -ResourceGroup "your-resource-group" `
    -WorkspaceName "your-azureml-workspace" `
    -KeyVaultName "your-keyvault-name"
```

### Linux/Mac (Bash)

```bash
# Run from the azureml-job folder
cd tutorials/02-core-integration/jobs/azureml-job
chmod +x run-azureml-job.sh

./run-azureml-job.sh \
    --subscription-id "your-subscription-id" \
    --resource-group "your-resource-group" \
    --workspace-name "your-azureml-workspace" \
    --key-vault-name "your-keyvault-name"
```

**Important**: The scripts run the job with `code: ../../` to access the notebook in the parent directory.

## 📋 Prerequisites

### 1. Azure CLI
```bash
# Check if installed
az --version

# Install if needed
# Windows: https://aka.ms/installazurecliwindows
# Linux: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
# Mac: brew install azure-cli
```

### 2. Azure ML Extension
```bash
# Install Azure ML extension
az extension add --name ml

# Or upgrade if already installed
az extension update --name ml
```

### 3. Login to Azure
```bash
az login
az account set --subscription "your-subscription-id"
```

### 4. Azure ML Compute Cluster
The script will create a compute cluster named `cpu-cluster` if it doesn't exist. Or specify a custom cluster:

```powershell
# Custom compute cluster
.\run-azureml-job.ps1 `
    -SubscriptionId "xxx" `
    -ResourceGroup "xxx" `
    -WorkspaceName "xxx" `
    -KeyVaultName "xxx" `
    -ComputeCluster "my-custom-cluster"
```

### 5. RBAC Permissions Required

**On Azure ML Workspace:**
- `Contributor` or `AzureML Data Scientist`

**On Key Vault:**
- `Key Vault Secrets User` (read) or `Key Vault Secrets Officer` (read/write)

**On Compute:**
- Managed identity must have same Key Vault permissions

## 🔧 Manual Submission

If you prefer to submit manually without the scripts:

```bash
# 1. Navigate to the azureml-job folder
cd tutorials/02-core-integration/jobs/azureml-job

# 2. Submit job (the YAML uses code: ../../ to access the notebook)
az ml job create \
    --file azureml-job.yml \
    --workspace-name your-workspace \
    --resource-group your-rg \
    --set inputs.subscription_id="xxx" \
    --set inputs.resource_group="xxx" \
    --set inputs.workspace_name="xxx" \
    --set inputs.key_vault_name="xxx" \
    --set inputs.databricks_secret_scope="azureml-kv-scope"
```

The output notebook will be saved at `jobs/azureml-job/output_AzureML_KeyVault_Integration.ipynb`.

## 📊 Monitor Job

### View Job Status
```bash
az ml job show \
    --name <job-name> \
    --workspace-name your-workspace \
    --resource-group your-rg
```

### Stream Logs
```bash
az ml job stream \
    --name <job-name> \
    --workspace-name your-workspace \
    --resource-group your-rg
```

### Download Outputs
```bash
az ml job download \
    --name <job-name> \
    --workspace-name your-workspace \
    --resource-group your-rg \
    --download-path ./outputs
```

The executed notebook will be in `outputs/jobs/azureml-job/output_AzureML_KeyVault_Integration.ipynb`.

## ⚙️ Customization

### Change Compute Resources

Edit [azureml-job.yml](azureml-job.yml):

```yaml
compute: azureml:your-cluster-name

resources:
  instance_count: 2  # Scale to multiple nodes
```

### Add More Input Parameters

Edit [azureml-job.yml](azureml-job.yml):

```yaml
inputs:
  custom_parameter:
    type: string
    default: "value"
```

Then pass to notebook:

```yaml
command: >-
  papermill notebook.ipynb output.ipynb
  -p custom_parameter ${{inputs.custom_parameter}}
```

### Change Python Environment

Edit [conda-env.yml](conda-env.yml) to add dependencies:

```yaml
dependencies:
  - pip:
      - your-package>=1.0.0
```

### Schedule Job

Create a schedule:

```bash
az ml schedule create \
    --file schedule.yml \
    --workspace-name your-workspace \
    --resource-group your-rg
```

Example `schedule.yml`:

```yaml
$schema: https://azuremlschemas.azureedge.net/latest/schedule.schema.json
name: weekly-keyvault-test
display_name: Weekly KeyVault Integration Test

trigger:
  type: recurrence
  frequency: week
  interval: 1
  schedule:
    hours: [0]
    minutes: [0]
    week_days: [monday]
  start_time: "2026-01-01T00:00:00"
  time_zone: UTC

create_job: azureml-job.yml
```

## 🔐 Security Best Practices

1. **Use Managed Identity** (already configured in YAML)
   ```yaml
   identity:
     type: managed
   ```

2. **Don't Hardcode Secrets** - Use inputs instead:
   ```yaml
   inputs:
     api_key:
       type: string
   ```

3. **Restrict Compute Access** - Use private endpoints for compute

4. **Enable Diagnostic Logs** - Monitor job execution

5. **Tag Jobs** - For cost tracking and governance
   ```yaml
   tags:
     project: integration-test
     cost-center: engineering
   ```

## 🐛 Troubleshooting

### Error: "Compute not found"
**Solution:** Ensure compute cluster exists or let script create it automatically

### Error: "Access denied to Key Vault"
**Solution:** Grant compute managed identity proper RBAC role on Key Vault

### Error: "Module not found"
**Solution:** Check conda-env.yml includes all required packages

### Error: "Papermill execution failed"
**Solution:** Test notebook locally first, check cell execution order

### Job Stuck in "Queuing"
**Solution:** Check compute cluster scaling settings and regional quotas

## 📚 Additional Resources

- [Azure ML CLI v2 Documentation](https://learn.microsoft.com/azure/machine-learning/how-to-train-cli)
- [Papermill Documentation](https://papermill.readthedocs.io/)
- [Azure ML Job Schema](https://azuremlschemas.azureedge.net/latest/commandJob.schema.json)
- [Azure ML Compute Clusters](https://learn.microsoft.com/azure/machine-learning/how-to-create-attach-compute-cluster)

---

**Need Help?** Check the main [README](README.md) or raise an issue in the repository.
