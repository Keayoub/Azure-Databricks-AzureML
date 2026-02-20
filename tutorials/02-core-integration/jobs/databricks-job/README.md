# Databricks-AzureML Integration Job

Simple, unified approach to test Databricks ↔ Azure ML integration using a single notebook and lightweight CLI tool.

---

## 📁 Files

| File | Purpose |
|------|---------|
| `adb-azureml-integration-unified.ipynb` | Single notebook with all integration tests |
| `databricks-azureml-job.ps1` | PowerShell CLI wrapper to create/run/manage jobs |

---

## ⚡ Quick Start

### Prerequisites
- Databricks workspace with credentials in secret scope `azureml-kv-scope`
- `DATABRICKS_TOKEN` environment variable set or enter when prompted
- Notebook uploaded to Databricks workspace

### Option 1: Using PowerShell Script (Recommended)

```powershell
# Navigate to folder
cd tutorials/02-core-integration/jobs/databricks-job

# Set token (or enter when prompted)
$env:DATABRICKS_TOKEN = "dapi..."

# Create job (one-time)
.\databricks-azureml-job.ps1 -Action create `
  -WorkspaceUrl "https://adb-xxx.azuredatabricks.net" `
  -NotebookPath "/Users/your-email/tutorials/Databricks_AzureML_Integration_Unified"

# Run job (anytime)
.\databricks-azureml-job.ps1 -Action run `
  -WorkspaceUrl "https://adb-xxx.azuredatabricks.net"

# List all jobs
.\databricks-azureml-job.ps1 -Action list `
  -WorkspaceUrl "https://adb-xxx.azuredatabricks.net"

# Delete job
.\databricks-azureml-job.ps1 -Action delete `
  -WorkspaceUrl "https://adb-xxx.azuredatabricks.net"
```

### Option 2: Using Databricks CLI

```bash
# Install databricks-cli
pip install databricks-cli

# Configure
databricks configure --token

# Create job
databricks jobs create --json '{
  "name": "AzureML-Integration-Test",
  "new_cluster": {
    "spark_version": "13.3.x-scala2.12",
    "node_type_id": "Standard_DS3_v2",
    "num_workers": 1
  },
  "notebook_task": {
    "notebook_path": "/Users/your-email/tutorials/Databricks_AzureML_Integration_Unified"
  }
}'

# Run job
databricks jobs run-now --job-id 123

# List jobs
databricks jobs list
```

---

## 📊 Integration Tests Included

✓ **Databricks → Azure ML** - Call Azure ML endpoint from notebook  
✓ **Azure ML → Databricks** - Load and run Databricks MLflow model  
✓ **Databricks Workspace Client** - Verify workspace API connectivity  
✓ **Full Integration Report** - Summary of all test results  

---

## 📋 Setup Steps

### 1. Prepare Databricks Workspace

Upload the integration notebook to Databricks:

```bash
# Using Databricks CLI
databricks workspace import \
  Databricks_AzureML_Integration_Unified.py \
  /Users/your-email/tutorials/Databricks_AzureML_Integration_Unified \
  --language PYTHON \
  --format SOURCE
```

Or manually in Databricks UI: **Workspace** → **Create Notebook** → Copy content

### 2. Create Secret Scope

In Databricks notebook or CLI:

```python
# Create secret scope
dbutils.secrets.createScope("azureml-kv-scope")

# Add Azure ML credentials
dbutils.secrets.put("azureml-kv-scope", "subscription-id", "your-subscription-id")
dbutils.secrets.put("azureml-kv-scope", "resource-group", "your-resource-group")
dbutils.secrets.put("azureml-kv-scope", "workspace-name", "your-azureml-workspace")
dbutils.secrets.put("azureml-kv-scope", "databricks-host", "https://adb-xxx.azuredatabricks.net")
dbutils.secrets.put("azureml-kv-scope", "databricks-token", "dapi...")
dbutils.secrets.put("azureml-kv-scope", "mlflow-model-name", "your-model-name")
dbutils.secrets.put("azureml-kv-scope", "azureml-endpoint-name", "your-endpoint-name")
```

### 3. Create and Run Job

Use the PowerShell script or Databricks CLI (see **Quick Start** above)

### 4. Monitor Execution

- View job in Databricks UI: **Workflows** → **Jobs**
- Check run logs for test results and integration report

---

## 🔧 Troubleshooting

### Secret scope not found?
```python
# List existing scopes
dbutils.secrets.listScopes()

# Create new scope if needed
dbutils.secrets.createScope("azureml-kv-scope")
```

### Token issues?
```bash
# Generate new token in Databricks UI
# Settings → User Settings → Access Tokens → Generate New Token

# Set environment variable
$env:DATABRICKS_TOKEN = "dapi..."

# Or pass directly to script
.\databricks-azureml-job.ps1 -Action create -Token "dapi..." ...
```

### Notebook not found?
```bash
# Upload notebook first
databricks workspace import Databricks_AzureML_Integration_Unified.py \
  /Users/your-email/tutorials/Databricks_AzureML_Integration_Unified \
  --language PYTHON --format SOURCE

# Then reference full path in job creation
...
-NotebookPath "/Users/your-email/tutorials/Databricks_AzureML_Integration_Unified"
```

### Cluster creation fails?
```powershell
# Use existing cluster instead
.\databricks-azureml-job.ps1 -Action create `
  -WorkspaceUrl "https://adb-xxx.azuredatabricks.net" `
  -NotebookPath "/Users/your-email/tutorials/Databricks_AzureML_Integration_Unified" `
  -ClusterId "0123-456789-abcdef"
```

---

## 📈 Architecture

```
Databricks Workspace
├── Notebook: Databricks_AzureML_Integration_Unified
│   ├── Test 1: Call Azure ML endpoint
│   ├── Test 2: Load MLflow model from Databricks
│   ├── Test 3: Verify Workspace API
│   └── Summary Report
└── Job: AzureML-Integration-Test
    └── Executes notebook on schedule or on-demand
```

---

## 📝 Notes

- **Simplified Approach**: Single notebook replaces 8+ task workflow (312-line JSON → streamlined Python)
- **Maintenance**: Edit one notebook vs managing complex JSON configurations
- **Performance**: Complete test suite runs in ~10 minutes
- **Reusability**: Job can be scheduled or run manually anytime
- **Extensibility**: Add more tests directly to the notebook

**Target Path**: `/Workspace/tutorials/02-core-integration/Databricks_KeyVault_Integration_Test`

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
