# Complete Databricks-AzureML Workflow

This workflow orchestrates **all 17 Databricks notebooks** in a logical execution order, providing comprehensive validation of Databricks-AzureML integration patterns.

## 📊 Workflow Overview

### Execution Flow
```
Quickstart (Validation)
    ↓
Core Integration (Foundational Patterns)
    ↓
ML Workflows (Feature → Train → Inference)
    ↓
MLOps Orchestration
    ↓
Unity Catalog Integration
    ↓
Enterprise Reference
```

### Task Breakdown (17 Total)

#### 1️⃣ Quickstart (2 tasks)
- **quickstart_integration_guide** - Introduction and integration overview
- **quickstart_test_models** - Quick test of Azure ML models from Databricks

#### 2️⃣ Core Integration (3 tasks)
- **core_complete_integration** - Complete reference for Databricks-AzureML integration
- **core_databricks_to_azureml** - Call AzureML endpoints from Databricks
- **core_keyvault_integration** - Test Key Vault integration from Databricks

#### 3️⃣ ML Workflows (5 tasks)
- **ml_feature_engineering** - Feature engineering and data preparation
- **ml_model_training** - Model training pipeline
- **ml_batch_prediction** - Batch prediction and scoring
- **ml_realtime_inference** - Real-time inference patterns
- **ml_testing_models** - Testing AzureML models

#### 4️⃣ MLOps Orchestration (3 tasks)
- **mlops_orchestration** - MLOps orchestration patterns
- **mlops_powershell** - PowerShell orchestration examples
- **mlops_integration_guide** - Comprehensive Databricks-AzureML integration guide

#### 5️⃣ Unity Catalog (3 tasks)
- **unity_catalog_integration** - Unity Catalog integration patterns
- **unity_deploy_endpoints** - Deploy model to three endpoints
- **unity_track_deploy** - Track with Databricks, deploy to AzureML

#### 6️⃣ Enterprise Reference (1 task)
- **enterprise_reference** - Enterprise reference integration patterns

## 🚀 Quick Start

### Prerequisites

1. **Databricks workspace** with notebooks uploaded to `/Workspace/tutorials/`
2. **Secret scope** configured with Azure credentials:
   ```bash
   # Required secrets in scope 'azureml-kv-scope':
   - subscription-id
   - resource-group
   - workspace-name
   - key-vault-name
   ```
3. **Databricks cluster** (existing) or auto-create job cluster
4. **Databricks token** for API access

### Option 1: Use Existing Cluster (Recommended for Testing)

```powershell
# PowerShell
.\create-complete-workflow.ps1 `
    -WorkspaceUrl "https://adb-xxx.azuredatabricks.net" `
    -ClusterId "0123-456789-abcdef" `
    -Token $env:DATABRICKS_TOKEN
```

```bash
# Bash
./create-complete-workflow.sh \
    -w "https://adb-xxx.azuredatabricks.net" \
    -c "0123-456789-abcdef" \
    -t "$DATABRICKS_TOKEN"
```

### Option 2: Auto-Create Job Cluster (Production)

```powershell
# PowerShell
.\create-complete-workflow.ps1 `
    -WorkspaceUrl "https://adb-xxx.azuredatabricks.net" `
    -CreateCluster `
    -RunNow
```

```bash
# Bash
./create-complete-workflow.sh \
    -w "https://adb-xxx.azuredatabricks.net" \
    -n \
    -r
```

## ⚙️ Configuration

### Secret Scope Setup

Create a Databricks secret scope backed by Azure Key Vault:

```bash
# Using Databricks CLI
databricks secrets create-scope --scope azureml-kv-scope

# Add secrets
databricks secrets put --scope azureml-kv-scope --key subscription-id
databricks secrets put --scope azureml-kv-scope --key resource-group
databricks secrets put --scope azureml-kv-scope --key workspace-name
databricks secrets put --scope azureml-kv-scope --key key-vault-name
```

### Cluster Configuration

**Option 1: Existing Cluster**
- Get cluster ID from Databricks UI: `Compute` → `<your-cluster>` → Copy ID
- Ensure cluster has required libraries installed

**Option 2: Job Cluster (Auto-created)**
- Config: 13.3.x Spark, Standard_DS3_v2, 2 workers
- Libraries installed automatically from notebook requirements

### Schedule Configuration

Default schedule (in `complete-workflow-job.json`):
```json
"schedule": {
    "quartz_cron_expression": "0 0 2 * * ?",
    "timezone_id": "America/New_York",
    "pause_status": "PAUSED"
}
```

- **Cron**: Daily at 2:00 AM Eastern
- **Status**: Paused by default (manual trigger only)
- **Modify**: Edit JSON or update via Databricks UI

## 🎯 Usage Scenarios

### Scenario 1: Comprehensive Integration Testing
Execute all notebooks to validate end-to-end Databricks-AzureML integration:
```powershell
.\create-complete-workflow.ps1 -WorkspaceUrl $WS_URL -ClusterId $CLUSTER_ID -RunNow
```

### Scenario 2: CI/CD Validation
Integrate into deployment pipeline to validate infrastructure:
```yaml
# Azure DevOps Pipeline
- task: PowerShell@2
  inputs:
    filePath: 'tutorials/02-core-integration/jobs/databricks-job/create-complete-workflow.ps1'
    arguments: '-WorkspaceUrl $(DATABRICKS_WORKSPACE) -ClusterId $(DATABRICKS_CLUSTER) -Token $(DATABRICKS_TOKEN) -RunNow'
```

### Scenario 3: Scheduled Smoke Tests
Enable schedule for nightly validation:
1. Create workflow with paused schedule
2. Update via UI: Jobs → Complete-Databricks-AzureML-Workflow → Schedule → Enable
3. Monitor email notifications for failures

### Scenario 4: Onboarding / Training
New team members can review workflow execution to understand integration patterns:
1. Create workflow
2. Run manually and review logs
3. Each task demonstrates specific integration pattern

## 📈 Monitoring & Troubleshooting

### View Workflow Status

**In Databricks UI:**
1. Navigate to `Workflows` → `Jobs`
2. Find `Complete-Databricks-AzureML-Workflow`
3. Click job → View run history and task details

**Via API:**
```bash
# Get recent runs
curl -X GET "$WORKSPACE_URL/api/2.1/jobs/runs/list?job_id=$JOB_ID" \
    -H "Authorization: Bearer $TOKEN"
```

### Common Issues

#### Issue: Secret Scope Not Found
```
⚠️ Warning: Secret scope 'azureml-kv-scope' not found
```
**Solution:** Create secret scope and add required secrets (see Configuration section)

#### Issue: Cluster Not Found
```
❌ Error: Cluster 0123-456789-abcdef does not exist
```
**Solution:** 
- Verify cluster ID: `databricks clusters list`
- Use `-CreateCluster` to auto-create job cluster

#### Issue: Notebook Not Found
```
❌ Error: Notebook path /Workspace/tutorials/... does not exist
```
**Solution:** Upload notebooks to Databricks workspace at correct paths

#### Issue: Task Failure Mid-Workflow
**Investigation:**
1. Click failed task in workflow UI
2. Review notebook output and error messages
3. Check Azure resource connectivity (AzureML workspace, Key Vault)

**Resolution:**
- Fix underlying issue (permissions, network, resources)
- Resume workflow from failed task: `Run now` → `Custom parameters` → Select start task

### Performance Optimization

**Reduce Execution Time:**
1. **Parallel Execution**: Remove task dependencies for independent notebooks
   ```json
   // Remove depends_on for parallel execution
   {
     "task_key": "task1",
     // "depends_on": [...],  // Remove this
     "notebook_task": {...}
   }
   ```

2. **Job Clusters**: Use job cluster per task for isolated execution
   ```json
   "job_clusters": [
     {"job_cluster_key": "quickstart-cluster", ...},
     {"job_cluster_key": "ml-workflow-cluster", ...}
   ]
   ```

3. **Skip Unnecessary Tasks**: Edit JSON to remove tasks not needed for your validation

## 📁 Files

| File | Purpose |
|------|---------|
| `complete-workflow-job.json` | Multi-task job definition (17 tasks) |
| `create-complete-workflow.ps1` | PowerShell creation/update script |
| `create-complete-workflow.sh` | Bash creation/update script |
| `COMPLETE-WORKFLOW.md` | This documentation |

## 🔗 Related Resources

- [Single Notebook Job Setup](README.md) - Run individual notebooks as jobs
- [Job Configuration Guide](../README.md) - Azure ML vs Databricks job comparison
- [Tutorial Documentation](../../README.md) - Notebook descriptions and prerequisites

## ⏱️ Expected Duration

| Phase | Tasks | Duration |
|-------|-------|----------|
| Quickstart | 2 | 10-15 min |
| Core Integration | 3 | 30-45 min |
| ML Workflows | 5 | 45-60 min |
| MLOps | 3 | 20-30 min |
| Unity Catalog | 3 | 25-35 min |
| Enterprise | 1 | 15-20 min |
| **Total** | **17** | **2-4 hours** |

*Duration varies based on cluster size, network latency, and Azure resource performance*

## 🎓 Learning Path

**Recommended approach for learning:**

1. **Start Simple**: Run single notebooks individually (see [README.md](README.md))
2. **Understand Patterns**: Review each notebook's code and outputs
3. **Run Workflow**: Execute complete workflow to see end-to-end integration
4. **Customize**: Modify workflow for your specific use cases

## 📞 Support

**Issues or Questions?**
- Check [troubleshooting section](#monitoring--troubleshooting)
- Review individual notebook documentation
- Validate Azure resource connectivity
- Check Databricks cluster logs

---

**🎉 Happy Integrating!**
