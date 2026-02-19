# Running AzureML_KeyVault_Integration Notebook as Databricks Job

This guide explains how to create and run the `AzureML_KeyVault_Integration.ipynb` notebook as a Databricks job using the Databricks Jobs API.

## 📁 Folder Structure

```
tutorials/02-core-integration/
├── AzureML_KeyVault_Integration.ipynb  ← The notebook to execute
└── jobs/
    └── databricks-job/                  ← You are here
        ├── job-definition.json          ← Job definition
        ├── create-databricks-job.ps1    ← Creation script
        └── README.md                    ← This file
```

**Note**: Upload the notebook to Databricks workspace at `/Workspace/tutorials/02-core-integration/AzureML_KeyVault_Integration`

## 📁 Files

- **job-definition.json** - Databricks job configuration
- **create-databricks-job.ps1** - PowerShell script to create/update job (Windows)
- **create-databricks-job.sh** - Bash script to create/update job (Linux/Mac)

## 🚀 Quick Start

### Windows (PowerShell)

```powershell
.\create-databricks-job.ps1 `
    -WorkspaceUrl "https://adb-1234567890123456.7.azuredatabricks.net" `
    -Token "dapi..."
```

### Linux/Mac (Bash)

```bash
chmod +x create-databricks-job.sh

./create-databricks-job.sh \
    --workspace-url "https://adb-1234567890123456.7.azuredatabricks.net" \
    --token "dapi..."
```

## 📋 Prerequisites

### 1. Upload Notebook to Databricks

Upload `../../AzureML_KeyVault_Integration.ipynb` to your Databricks workspace:

```bash
# Using Databricks CLI (from the jobs/databricks-job folder)
databricks workspace import \
    ../../AzureML_KeyVault_Integration.ipynb \
    /Workspace/tutorials/02-core-integration/AzureML_KeyVault_Integration \
    --language PYTHON \
    --format JUPYTER
```

Or use the Databricks UI: **Workspace** → **Import** → Select file

**Target Path**: `/Workspace/tutorials/02-core-integration/AzureML_KeyVault_Integration`

### 2. Create Secret Scope

Create a Key Vault-backed secret scope:

1. Navigate to: `https://<databricks-instance>#secrets/createScope`
2. Configure:
   - **Scope Name**: `azureml-kv-scope`
   - **Manage Principal**: `All Users` or restrict as needed
   - **DNS Name**: `https://<your-keyvault>.vault.azure.net`
   - **Resource ID**: `/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<kv-name>`

### 3. Add Secrets to Key Vault

Add these secrets to your Key Vault:

```bash
# Using Azure CLI
az keyvault secret set --vault-name <kv-name> --name subscription-id --value "<subscription-id>"
az keyvault secret set --vault-name <kv-name> --name resource-group --value "<resource-group>"
az keyvault secret set --vault-name <kv-name> --name workspace-name --value "<azureml-workspace>"
az keyvault secret set --vault-name <kv-name> --name keyvault-name --value "<kv-name>"
```

### 4. Get Databricks Token

Generate a personal access token:

1. Go to **User Settings** → **Access Tokens**
2. Click **Generate New Token**
3. Copy the token (shown only once)

Or set environment variable:

```powershell
# PowerShell
$env:DATABRICKS_TOKEN = "dapi..."

# Bash
export DATABRICKS_TOKEN="dapi..."
```

### 5. Permissions Required

- **Workspace**: Permission to create jobs
- **Clusters**: Permission to create/manage clusters
- **Secret Scope**: Permission to read secrets

## 🔧 Advanced Usage

### Update Existing Job

```powershell
# PowerShell
.\create-databricks-job.ps1 `
    -WorkspaceUrl "https://adb-xxx.azuredatabricks.net" `
    -Update

# Bash
./create-databricks-job.sh \
    --workspace-url "https://adb-xxx.azuredatabricks.net" \
    --update
```

### Custom Parameters

```powershell
# PowerShell
.\create-databricks-job.ps1 `
    -WorkspaceUrl "https://adb-xxx.azuredatabricks.net" `
    -NotebookPath "/Users/me/MyNotebook" `
    -JobName "Custom-Job-Name" `
    -SecretScope "my-secret-scope"

# Bash
./create-databricks-job.sh \
    --workspace-url "https://adb-xxx.azuredatabricks.net" \
    --notebook-path "/Users/me/MyNotebook" \
    --job-name "Custom-Job-Name" \
    --secret-scope "my-secret-scope"
```

### Use Azure CLI Authentication

Scripts automatically try Azure CLI if token not provided:

```bash
# Login to Azure
az login

# Script will use Azure AD token for Databricks
./create-databricks-job.sh --workspace-url "https://adb-xxx.azuredatabricks.net"
```

## 📊 Manage Jobs

### Run Job Manually

```bash
# Using Databricks CLI
databricks jobs run-now --job-id <job-id>

# Using REST API
curl -X POST "https://<workspace-url>/api/2.1/jobs/run-now" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"job_id": <job-id>}'
```

### Monitor Job Runs

```bash
# List runs
databricks jobs runs list --job-id <job-id>

# Get run details
databricks jobs runs get --run-id <run-id>

# Get run output
databricks jobs runs get-output --run-id <run-id>
```

### Enable Schedule

The job is created with a **paused** schedule (every Monday at 09:00 UTC). To enable:

1. Open job in Databricks UI
2. Go to **Schedule** tab
3. Click **Enable** or edit schedule

Or via API:

```bash
curl -X POST "https://<workspace-url>/api/2.1/jobs/update" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "job_id": <job-id>,
        "new_settings": {
            "schedule": {
                "quartz_cron_expression": "0 0 9 ? * MON",
                "timezone_id": "UTC",
                "pause_status": "UNPAUSED"
            }
        }
    }'
```

## ⚙️ Job Configuration

### Cluster Configuration

The job uses a **single-node** cluster:

```json
{
  "spark_version": "13.3.x-scala2.12",
  "node_type_id": "Standard_DS3_v2",
  "num_workers": 0,
  "data_security_mode": "USER_ISOLATION"
}
```

To use a different cluster, edit [job-definition.json](job-definition.json):

```json
{
  "node_type_id": "Standard_DS4_v2",
  "num_workers": 2
}
```

### Use Existing Cluster

Replace `job_clusters` with `existing_cluster_id` in [job-definition.json](job-definition.json):

```json
{
  "tasks": [{
    "existing_cluster_id": "1234-567890-abc123",
    "notebook_task": { ... }
  }]
}
```

### Notebook Parameters

Parameters are passed via secret scope references:

```json
{
  "base_parameters": {
    "AZURE_SUBSCRIPTION_ID": "{{secrets/azureml-kv-scope/subscription-id}}",
    "KEY_VAULT_NAME": "{{secrets/azureml-kv-scope/keyvault-name}}"
  }
}
```

To pass literal values instead:

```json
{
  "base_parameters": {
    "AZURE_SUBSCRIPTION_ID": "your-actual-subscription-id"
  }
}
```

### Add Email Notifications

Edit [job-definition.json](job-definition.json):

```json
{
  "email_notifications": {
    "on_start": ["user@company.com"],
    "on_success": ["user@company.com"],
    "on_failure": ["admin@company.com"],
    "no_alert_for_skipped_runs": false
  }
}
```

### Add Webhook Notifications

```json
{
  "webhook_notifications": {
    "on_failure": [{
      "id": "webhook-id-from-create"
    }]
  }
}
```

## 🐛 Troubleshooting

### Error: "Notebook not found"

**Solution**: Upload notebook to exact path specified in `notebook_path`

### Error: "Secret scope does not exist"

**Solution**: Create Key Vault-backed secret scope at `#secrets/createScope`

### Error: "Secret not found"

**Solution**: Add required secrets to Key Vault (subscription-id, resource-group, etc.)

### Error: "Invalid access token"

**Solution**: Generate new PAT token or re-authenticate with Azure CLI

### Job Fails with "Module not found"

**Solution**: Install required packages in cluster init script or notebook:

```python
%pip install azure-ai-ml azure-identity azure-keyvault-secrets
dbutils.library.restartPython()
```

### Job Stuck in "Pending"

**Solution**: Check cluster creation permissions and compute quotas

## 🔐 Security Best Practices

1. **Use Secret Scopes** - Never hardcode credentials
2. **Key Vault Backend** - Use Key Vault-backed secret scopes for centralized management
3. **Least Privilege** - Grant minimal permissions to service principals
4. **Rotate Tokens** - Regularly rotate PAT tokens
5. **Monitor Access** - Enable audit logging for job runs
6. **Private Endpoints** - Use private connectivity for Key Vault access

## 📚 Additional Resources

- [Databricks Jobs API](https://docs.databricks.com/dev-tools/api/latest/jobs.html)
- [Databricks Secret Scopes](https://docs.databricks.com/security/secrets/secret-scopes.html)
- [Azure Key Vault Integration](https://docs.databricks.com/security/secrets/secret-scopes.html#create-an-azure-key-vault-backed-secret-scope)
- [Databricks CLI](https://docs.databricks.com/dev-tools/cli/index.html)

---

**Need Help?** Check the parent [README](../README.md) or raise an issue in the repository.
