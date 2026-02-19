# Running AzureML_KeyVault_Integration Notebook as a Job

This notebook can be run as a scheduled or on-demand job in both **Azure ML** and **Databricks**. Choose the platform that best fits your workflow.

## 🎯 Choose Your Platform

### Option 1: Azure ML Job
Run the notebook on **Azure ML compute clusters** using `az ml` CLI.

**Best for:**
- Teams primarily using Azure ML
- Integration with Azure ML pipelines
- Centralized ML operations in Azure

📂 [Go to Azure ML Job Setup →](azureml-job/)

---

### Option 2: Databricks Job
Run the notebook on **Databricks clusters** using Jobs API.

**Best for:**
- Teams primarily using Databricks
- Access to Databricks-specific features (Delta Lake, Unity Catalog)
- Spark-based workloads

📂 [Go to Databricks Job Setup →](databricks-job/)

---

## 📊 Quick Comparison

| Feature | Azure ML Job | Databricks Job |
|---------|-------------|----------------|
| **Execution Engine** | Papermill on Azure ML compute | Native Databricks notebooks |
| **Authentication** | Azure CLI + `az ml` | Databricks API + PAT token |
| **Scheduling** | Azure ML Schedules | Databricks Job Scheduler |
| **Compute** | Azure ML compute clusters | Databricks clusters |
| **Cost** | Azure ML compute pricing | Databricks DBU + VM pricing |
| **Secret Management** | Key Vault (direct RBAC) | Key Vault-backed secret scopes |
| **Output Format** | Executed notebook (.ipynb) | Notebook results in workspace |
| **CI/CD Integration** | Azure DevOps, GitHub Actions | Databricks CLI, REST API |
| **Monitoring** | Azure ML Studio | Databricks Jobs UI |

## 🚀 Quick Start Examples

### Azure ML (PowerShell)
```powershell
# Navigate to the azureml-job folder
cd tutorials/02-core-integration/jobs/azureml-job

.\run-azureml-job.ps1 `
    -SubscriptionId "xxx" `
    -ResourceGroup "xxx" `
    -WorkspaceName "xxx" `
    -KeyVaultName "xxx"
```

### Databricks (PowerShell)
```powershell
# Navigate to the databricks-job folder
cd tutorials/02-core-integration/jobs/databricks-job

.\create-databricks-job.ps1 `
    -WorkspaceUrl "https://adb-xxx.azuredatabricks.net" `
    -Token "dapi..."
```

**Note**: Both jobs execute the notebook located at `../../AzureML_KeyVault_Integration.ipynb`

---

## 📚 Documentation

- **Azure ML Job**: [azureml-job/README.md](azureml-job/README.md)
- **Databricks Job**: [databricks-job/README.md](databricks-job/README.md)
- **Notebook**: [../AzureML_KeyVault_Integration.ipynb](../AzureML_KeyVault_Integration.ipynb)

## 🔑 Common Prerequisites

Both platforms require:

1. **Azure Resources**
   - Azure ML workspace
   - Azure Key Vault
   - Appropriate RBAC roles

2. **Secrets in Key Vault**
   ```bash
   az keyvault secret set --vault-name <kv> --name subscription-id --value "xxx"
   az keyvault secret set --vault-name <kv> --name resource-group --value "xxx"
   az keyvault secret set --vault-name <kv> --name workspace-name --value "xxx"
   az keyvault secret set --vault-name <kv> --name keyvault-name --value "xxx"
   ```

3. **Permissions**
   - Key Vault: `Key Vault Secrets User` or `Key Vault Secrets Officer`
   - Azure ML: `Contributor` or `AzureML Data Scientist`

---

## 🎓 Which Should You Choose?

### Choose Azure ML if:
- ✅ You're building ML pipelines in Azure ML
- ✅ You want to leverage Azure ML's experiment tracking
- ✅ Your team is already using `az ml` CLI
- ✅ You need integration with Azure DevOps/GitHub Actions

### Choose Databricks if:
- ✅ You're primarily working in Databricks
- ✅ You need Spark-based data processing
- ✅ You want to use Delta Lake or Unity Catalog features
- ✅ Your notebooks have Databricks-specific code (dbutils, etc.)

### Use Both if:
- ✅ You have hybrid workflows across platforms
- ✅ You want to validate cross-platform compatibility
- ✅ Different teams use different platforms

---

[← Back to Tutorial](../)
