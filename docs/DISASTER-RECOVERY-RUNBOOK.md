# Disaster Recovery Runbook
## Azure Databricks, Azure ML, and AI Foundry Platform

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Recovery Objectives](#recovery-objectives)
3. [Architecture Overview](#architecture-overview)
4. [Backup Strategy](#backup-strategy)
5. [Disaster Scenarios](#disaster-scenarios)
6. [Recovery Procedures](#recovery-procedures)
7. [Runbook Procedures](#runbook-procedures)
8. [Validation & Testing](#validation--testing)
9. [Contacts & Escalation](#contacts--escalation)
10. [Appendix](#appendix)

---

## Executive Summary

### Purpose
This runbook provides step-by-step procedures for recovering the Azure Databricks, Azure ML, and AI Foundry platform in the event of a disaster, outage, or data loss incident.

### Scope
Covers disaster recovery for:
- **Infrastructure**: Virtual networks, storage accounts, Key Vault, ACR
- **Databricks**: Workspaces, Unity Catalog metastores, notebooks, jobs
- **Azure ML**: Workspaces, models, datasets, compute
- **AI Foundry**: Hubs, projects, connections
- **Data**: Unity Catalog data, ML datasets, model artifacts

### Quick Reference
| **Scenario** | **RTO** | **RPO** | **Runbook Section** |
|--------------|---------|---------|---------------------|
| Region Outage | 4 hours | 1 hour | [Section 7.1](#71-region-failover) |
| Storage Account Deletion | 2 hours | 0 (soft delete) | [Section 7.2](#72-storage-account-recovery) |
| Databricks Workspace Deletion | 3 hours | 1 hour | [Section 7.3](#73-databricks-workspace-recovery) |
| Unity Catalog Metastore Loss | 4 hours | 24 hours | [Section 7.4](#74-unity-catalog-recovery) |
| Azure ML Workspace Deletion | 2 hours | 1 hour | [Section 7.5](#75-azure-ml-workspace-recovery) |
| Data Corruption/Deletion | 1 hour | 1 hour | [Section 7.6](#76-data-recovery) |
| Complete Infrastructure Loss | 8 hours | 24 hours | [Section 7.7](#77-full-disaster-recovery) |

---

## Recovery Objectives

### RTO (Recovery Time Objective)
Maximum acceptable downtime before business-critical operations must be restored.

| **Component** | **RTO** | **Justification** |
|---------------|---------|-------------------|
| Networking (VNet, NSG) | 1 hour | Foundation for all services |
| Storage Accounts | 2 hours | Data layer for all workloads |
| Key Vault | 1 hour | Secrets required for authentication |
| Container Registry | 2 hours | Required for ML model deployment |
| Databricks Workspace | 3 hours | Analytics and ML workloads |
| Unity Catalog Metastore | 4 hours | Data governance layer |
| Azure ML Workspace | 2 hours | Model training and deployment |
| AI Foundry Hub | 2 hours | AI application development |

### RPO (Recovery Point Objective)
Maximum acceptable data loss measured in time.

| **Data Type** | **RPO** | **Backup Method** |
|---------------|---------|-------------------|
| Infrastructure-as-Code | 0 (Git-tracked) | GitHub repository |
| Unity Catalog Metadata | 24 hours | Daily export to ADLS Gen2 |
| Databricks Notebooks | 1 hour | Git sync + workspace export |
| Databricks Jobs | 1 hour | Terraform state + API export |
| ML Models | 1 hour | Azure ML model registry (GRS) |
| ML Datasets | 24 hours | ADLS Gen2 with GRS replication |
| Application Data | 1 hour | Continuous replication (GRS/ZRS) |
| Key Vault Secrets | 0 (soft delete enabled) | Azure built-in soft delete |

---

## Architecture Overview

### Regional Deployment
- **Primary Region**: Canada East
- **Secondary Region**: Canada Central (for failover)
- **Replication Strategy**: GRS (Geo-Redundant Storage) for critical data

### Resource Groups
```
├── rg-{env}-{project}-shared        # VNet, Storage, Key Vault, ACR, Monitoring
├── rg-{env}-{project}-databricks    # Databricks workspace
├── rg-{env}-{project}-ai-platform   # Azure ML, AI Foundry, AI Search, Cosmos DB
└── rg-{env}-{project}-compute       # AKS, Container Apps (if deployed)
```

### Critical Dependencies
```
Databricks Workspace
  ├─> VNet (VNet injection)
  ├─> Storage Account (Unity Catalog)
  ├─> Access Connector (Managed Identity)
  └─> Key Vault (Secrets)

Azure ML Workspace
  ├─> Storage Account (Datasets, models)
  ├─> Key Vault (Secrets)
  ├─> Container Registry (Docker images)
  └─> Application Insights (Monitoring)

AI Foundry Hub
  ├─> Storage Account (Projects)
  ├─> Key Vault (Connections)
  └─> Azure ML Workspace (Compute)
```

---

## Backup Strategy

### 4.1 Infrastructure-as-Code Backup
**Location:** GitHub Repository  
**Frequency:** Every commit (real-time)  
**Retention:** Unlimited (Git history)

**Files Backed Up:**
- `/infra/*.bicep` - Azure infrastructure
- `/terraform/**/*.tf` - Unity Catalog configuration
- `/.github/workflows/*.yml` - CI/CD pipelines
- `/docs/**/*.md` - Documentation

**Recovery Method:**
```bash
# Clone repository
git clone https://github.com/your-org/Azure-Databricks-AzureML.git
cd Azure-Databricks-AzureML

# Checkout specific commit if needed
git checkout <commit-hash>

# Deploy infrastructure
azd provision --environment prod
```

### 4.2 Unity Catalog Metadata Backup
**Location:** `{storage-account}/unity-catalog-backups/{metastore-id}/`  
**Frequency:** Daily at 02:00 UTC  
**Retention:** 30 days

**Backup Script:** `/infra/scripts/backup-unity-catalog.ps1`  
**Automated:** Yes (Azure Automation Runbook)

**Items Backed Up:**
- Metastore configuration
- Catalog schemas
- External locations
- Storage credentials
- Grants and permissions

**Manual Backup:**
```bash
# Export metastore metadata
databricks unity-catalog metastores get --id <metastore-id> > metastore-backup.json

# Export all catalogs
databricks unity-catalog catalogs list --output JSON > catalogs-backup.json

# Export schemas for each catalog
for catalog in $(databricks unity-catalog catalogs list --output JSON | jq -r '.[].name'); do
  databricks unity-catalog schemas list --catalog-name $catalog --output JSON > schemas-$catalog-backup.json
done
```

### 4.3 Databricks Workspace Backup
**Location:** `{storage-account}/databricks-backups/{workspace-id}/`  
**Frequency:** Hourly (notebooks), Daily (jobs, clusters)  
**Retention:** 90 days

**Backup Methods:**
1. **Git Integration:** Real-time sync of notebooks to GitHub
2. **Workspace Export API:** Automated export of workspace objects
3. **Terraform State:** Infrastructure configuration

**Automated Backup Script:**
```powershell
# /infra/scripts/backup-databricks-workspace.ps1

$workspaceUrl = "https://<workspace-url>"
$token = Get-AzKeyVaultSecret -VaultName "kv-{env}-{project}" -Name "databricks-token" -AsPlainText

# Export all notebooks
databricks workspace export_dir --profile backup / /backups/notebooks/$(Get-Date -Format 'yyyy-MM-dd')

# Export jobs
databricks jobs list --output JSON | Out-File "jobs-backup-$(Get-Date -Format 'yyyy-MM-dd').json"

# Export cluster policies
databricks cluster-policies list --output JSON | Out-File "policies-backup-$(Get-Date -Format 'yyyy-MM-dd').json"

# Upload to storage account
$storageAccount = "st{env}{project}shared"
$containerName = "databricks-backups"
azcopy copy "*.json" "https://$storageAccount.blob.core.windows.net/$containerName/$(Get-Date -Format 'yyyy-MM-dd')/" --recursive
```

### 4.4 Azure ML Workspace Backup
**Location:** Azure ML model registry (GRS replicated)  
**Frequency:** Continuous (model registration)  
**Retention:** All model versions retained

**Backed Up Items:**
- **Models:** Automatically versioned and replicated
- **Datasets:** Stored in ADLS Gen2 with GRS
- **Environments:** Exported as YAML/Dockerfile
- **Compute Configurations:** Stored in Terraform state

**Manual Model Export:**
```python
from azureml.core import Workspace, Model

ws = Workspace.from_config()

# Export all models
for model in Model.list(ws):
    model.download(target_dir=f'./model-backups/{model.name}/{model.version}')
    
# Export environment definitions
from azureml.core import Environment
for env in Environment.list(ws):
    env_obj = Environment.get(ws, name=env)
    env_obj.save_to_directory(path=f'./env-backups/{env}', overwrite=True)
```

### 4.5 Storage Account Backup
**Type:** Azure Blob Storage Soft Delete + GRS Replication  
**Frequency:** Continuous  
**Retention:** 14 days (soft delete), Unlimited (GRS)

**Configuration:**
- **Soft Delete:** Enabled (14 days)
- **Blob Versioning:** Enabled
- **Point-in-Time Restore:** Enabled (7 days)
- **Replication:** GRS (Geo-Redundant Storage)
- **Change Feed:** Enabled

### 4.6 Key Vault Backup
**Type:** Soft Delete + Purge Protection  
**Frequency:** Continuous  
**Retention:** 90 days

**Configuration:**
- **Soft Delete:** Enabled (90 days)
- **Purge Protection:** Enabled (cannot be disabled)
- **Backup:** Manual export for disaster recovery

**Manual Backup:**
```powershell
# Export all secrets (names only, not values)
$keyVaultName = "kv-{env}-{project}"
$secrets = Get-AzKeyVaultSecret -VaultName $keyVaultName

$secrets | Select-Object Name, @{N='Version';E={$_.Version}}, @{N='Enabled';E={$_.Enabled}} | 
    Export-Csv -Path "keyvault-inventory-$(Get-Date -Format 'yyyy-MM-dd').csv" -NoTypeInformation
```

---

## Disaster Scenarios

### 5.1 Regional Outage
**Trigger:** Azure region completely unavailable  
**Impact:** All services in primary region inaccessible  
**Recovery:** Failover to secondary region (Canada Central)

### 5.2 Storage Account Deletion
**Trigger:** Accidental or malicious deletion of storage account  
**Impact:** Data loss, Databricks/ML workloads fail  
**Recovery:** Restore from soft delete (14 days) or GRS failover

### 5.3 Databricks Workspace Deletion
**Trigger:** Workspace accidentally deleted  
**Impact:** Loss of notebooks, jobs, cluster configs  
**Recovery:** Redeploy workspace, restore from backup

### 5.4 Unity Catalog Metastore Corruption
**Trigger:** Metastore metadata corrupted or deleted  
**Impact:** Loss of data governance, table access fails  
**Recovery:** Restore metastore from backup, reassign to workspace

### 5.5 Azure ML Workspace Deletion
**Trigger:** Workspace accidentally deleted  
**Impact:** Loss of experiments, models, compute  
**Recovery:** Redeploy workspace, restore models from registry

### 5.6 Network Configuration Corruption
**Trigger:** VNet, NSG, or private endpoint misconfiguration  
**Impact:** Connectivity loss between services  
**Recovery:** Redeploy networking from Bicep

### 5.7 Complete Infrastructure Loss
**Trigger:** Subscription deletion, ransomware, catastrophic failure  
**Impact:** Total platform unavailability  
**Recovery:** Full redeployment from IaC + data restoration

---

## Recovery Procedures

### 6.1 Pre-Recovery Checklist
Before starting any recovery procedure:

- [ ] **Assess Incident Scope:** Determine what failed and why
- [ ] **Notify Stakeholders:** Alert platform users of outage
- [ ] **Open Incident Ticket:** Document incident in ticketing system
- [ ] **Assign Incident Commander:** Designate single point of contact
- [ ] **Preserve Evidence:** Take screenshots, save logs before changes
- [ ] **Verify Backups:** Confirm latest backups are available and valid
- [ ] **Gather Credentials:** Ensure access to Azure Portal, GitHub, Key Vault
- [ ] **Review Runbook:** Identify correct recovery procedure

### 6.2 Post-Recovery Checklist
After completing recovery:

- [ ] **Validate Services:** Run smoke tests on all restored components
- [ ] **Verify Data Integrity:** Check critical datasets for completeness
- [ ] **Test Connectivity:** Ensure all private endpoints and NSGs work
- [ ] **Notify Stakeholders:** Inform users platform is restored
- [ ] **Update Documentation:** Record incident details and lessons learned
- [ ] **Conduct Post-Mortem:** Schedule retrospective meeting
- [ ] **Update Runbook:** Incorporate learnings from incident

---

## Runbook Procedures

### 7.1 Region Failover
**Scenario:** Primary region (Canada East) unavailable  
**RTO:** 4 hours | **RPO:** 1 hour  
**Trigger Criteria:** Region-wide Azure outage > 30 minutes

#### Prerequisites
- Secondary region (Canada Central) configured
- GRS-replicated storage accounts
- Terraform state available
- Azure DevOps/GitHub Actions available

#### Procedure
```bash
# Step 1: Verify region outage
az account list-locations --query "[?name=='canadaeast'].metadata.regionCategory" --output table

# Step 2: Initiate storage account failover (if automatic failover not configured)
$storageAccounts = @("st{env}{project}shared", "st{env}{project}uc")
foreach ($sa in $storageAccounts) {
    az storage account failover --name $sa --resource-group rg-{env}-{project}-shared --yes
}
# WARNING: This is irreversible and takes 1-2 hours. Data becomes locally redundant (LRS).

# Step 3: Update Bicep parameters for secondary region
# Edit infra/main.bicepparam
location = 'canadacentral'  # Change from canadaeast

# Step 4: Deploy infrastructure to secondary region
azd provision --environment prod-dr

# Step 5: Update DNS/Application Gateway to point to new region
# (Manual step - depends on your DNS configuration)

# Step 6: Restore Unity Catalog metastore
cd terraform/environments
terraform init
terraform plan -var="location=canadacentral" -out=dr-plan.tfplan
terraform apply dr-plan.tfplan

# Step 7: Restore Databricks workspace objects
./infra/scripts/restore-databricks-workspace.ps1 -WorkspaceUrl "https://<new-workspace-url>" -BackupDate "2025-01-15"

# Step 8: Validate all services
./infra/scripts/validate-deployment.ps1 -Environment prod-dr
```

#### Validation
```powershell
# Check all resources deployed
az resource list --resource-group rg-prod-dr-{project}-shared --output table

# Test Databricks connectivity
databricks workspace list --profile prod-dr

# Test Azure ML
az ml workspace show --name mlw-prod-dr-{project} --resource-group rg-prod-dr-{project}-ai-platform

# Test storage account accessibility
az storage blob list --account-name stproddrshared --container-name unity-catalog --auth-mode login

# Run smoke tests
pytest tests/integration/test_platform_smoke.py --env=prod-dr
```

---

### 7.2 Storage Account Recovery
**Scenario:** Storage account deleted or corrupted  
**RTO:** 2 hours | **RPO:** 0 (soft delete)  
**Trigger Criteria:** Storage account inaccessible or deleted

#### Procedure
```powershell
# Step 1: Check if storage account is soft-deleted
az storage account list --query "[?name=='st{env}{project}shared'].{Name:name, State:provisioningState}" --output table

# Step 2: Recover soft-deleted storage account (14-day window)
az storage account restore --name st{env}{project}shared --resource-group rg-{env}-{project}-shared --deleted-version <version-id>

# Step 3: If past soft delete window, restore from GRS failover
az storage account failover --name st{env}{project}shared --resource-group rg-{env}-{project}-shared --yes

# Step 4: If complete loss, redeploy storage account from Bicep
azd provision --environment prod --component storage

# Step 5: Restore data from backup (if needed)
# Point-in-time restore (7-day window)
az storage blob restore --account-name st{env}{project}shared \
  --time-to-restore "2025-01-15T12:00:00Z" \
  --blob-range container1 container2

# Step 6: Re-grant storage account access to managed identities
$accessConnectorId = az databricks access-connector list --resource-group rg-{env}-{project}-shared --query "[0].id" -o tsv
az role assignment create --assignee $accessConnectorId --role "Storage Blob Data Contributor" --scope /subscriptions/{sub-id}/resourceGroups/rg-{env}-{project}-shared/providers/Microsoft.Storage/storageAccounts/st{env}{project}shared

# Step 7: Validate Unity Catalog access
databricks unity-catalog external-locations list --profile prod
```

#### Validation
```bash
# Test storage account connectivity
az storage blob list --account-name st{env}{project}shared --container-name unity-catalog --auth-mode login

# Test Databricks access to storage
databricks fs ls abfss://unity-catalog@st{env}{project}shared.dfs.core.windows.net/

# Verify blob versioning and soft delete still enabled
az storage account blob-service-properties show --account-name st{env}{project}shared --query "{SoftDelete:deleteRetentionPolicy.enabled, Versioning:isVersioningEnabled}"
```

---

### 7.3 Databricks Workspace Recovery
**Scenario:** Databricks workspace deleted or corrupted  
**RTO:** 3 hours | **RPO:** 1 hour  
**Trigger Criteria:** Workspace inaccessible, notebooks/jobs missing

#### Procedure
```bash
# Step 1: Redeploy Databricks workspace from Bicep
azd provision --environment prod --component databricks

# Step 2: Create new Unity Catalog metastore assignment (if needed)
cd terraform/environments
terraform apply -target=databricks_metastore_assignment.this

# Step 3: Restore workspace objects from backup
$latestBackup = Get-ChildItem "https://st{env}{project}shared.blob.core.windows.net/databricks-backups" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

# Download backup
azcopy copy $latestBackup.Uri ./restore-temp --recursive

# Import notebooks
databricks workspace import_dir ./restore-temp/notebooks / --overwrite

# Restore jobs from JSON
$jobs = Get-Content ./restore-temp/jobs-backup.json | ConvertFrom-Json
foreach ($job in $jobs.jobs) {
    $jobConfig = $job | ConvertTo-Json -Depth 10
    databricks jobs create --json $jobConfig
}

# Step 4: Restore cluster policies
$policies = Get-Content ./restore-temp/policies-backup.json | ConvertFrom-Json
foreach ($policy in $policies.policies) {
    databricks cluster-policies create --json ($policy | ConvertTo-Json -Depth 10)
}

# Step 5: Redeploy operational configuration from Terraform
cd terraform/environments
terraform apply -target=module.workspace_config -target=module.cluster_policies -target=module.instance_pools -target=module.secret_scopes
```

#### Validation
```bash
# Verify workspace accessible
databricks workspace list --profile prod

# Check notebooks restored
databricks workspace list / --profile prod

# Verify Unity Catalog access
databricks unity-catalog catalogs list --profile prod

# Test job execution
databricks jobs run-now --job-id <test-job-id> --profile prod
```

---

### 7.4 Unity Catalog Recovery
**Scenario:** Unity Catalog metastore corrupted or deleted  
**RTO:** 4 hours | **RPO:** 24 hours  
**Trigger Criteria:** Metastore assignment lost, catalogs inaccessible

#### Procedure
```bash
# Step 1: Check metastore status
databricks unity-catalog metastores list --profile account

# Step 2: If metastore deleted, restore from backup
$backupDate = "2025-01-15"
$backupPath = "https://st{env}{project}shared.blob.core.windows.net/unity-catalog-backups/$backupDate"

# Download backup
azcopy copy $backupPath ./uc-restore-temp --recursive

# Step 3: Recreate metastore using Terraform
cd terraform/metastore
terraform init
terraform apply -var="metastore_name=metastore-{env}-{project}-restored"

# Step 4: Restore catalogs
$catalogs = Get-Content ./uc-restore-temp/catalogs-backup.json | ConvertFrom-Json
foreach ($catalog in $catalogs) {
    databricks unity-catalog catalogs create --name $catalog.name --storage-location $catalog.storage_location --profile prod
}

# Step 5: Restore schemas
foreach ($catalog in $catalogs) {
    $schemas = Get-Content "./uc-restore-temp/schemas-$($catalog.name)-backup.json" | ConvertFrom-Json
    foreach ($schema in $schemas.schemas) {
        databricks unity-catalog schemas create --catalog-name $catalog.name --name $schema.name --profile prod
    }
}

# Step 6: Restore external locations
databricks unity-catalog external-locations create --name "bronze-data" --url "abfss://bronze@st{env}{project}uc.dfs.core.windows.net/" --credential-name "uc-storage-credential" --profile prod

# Step 7: Restore grants (from backup)
# (This must be scripted based on your backup format)

# Step 8: Assign metastore to workspace
cd terraform/environments
terraform apply -target=databricks_metastore_assignment.this
```

#### Validation
```bash
# Verify metastore assignment
databricks unity-catalog metastores get-assignment --workspace-id <workspace-id> --profile account

# List catalogs
databricks unity-catalog catalogs list --profile prod

# Test table access
databricks sql-query --sql "SELECT * FROM dev_lob_team_1.bronze.sample_table LIMIT 10" --profile prod
```

---

### 7.5 Azure ML Workspace Recovery
**Scenario:** Azure ML workspace deleted  
**RTO:** 2 hours | **RPO:** 1 hour  
**Trigger Criteria:** Workspace inaccessible, models missing

#### Procedure
```bash
# Step 1: Redeploy Azure ML workspace from Bicep
azd provision --environment prod --component azureml

# Step 2: Restore models from registry
# Models are stored in GRS storage account and automatically replicated
# If workspace deleted, models are still in storage, just need to re-register

# Connect to workspace
from azureml.core import Workspace
ws = Workspace.from_config()

# Re-register models from storage
from azureml.core import Model
model = Model.register(
    workspace=ws,
    model_path='azureml://subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{sa}/blobServices/default/containers/azureml/paths/models/model-v1',
    model_name='my-model',
    tags={'restored': 'true'}
)

# Step 3: Restore compute targets
cd terraform/environments
terraform apply -target=azurerm_machine_learning_compute_cluster.this

# Step 4: Restore environment definitions from backup
# (Environments are YAML files backed up to Git)
az ml environment create --file ./ml-environments/sklearn-env.yml --resource-group rg-{env}-{project}-ai-platform --workspace-name mlw-{env}-{project}

# Step 5: Re-create datasets
from azureml.core import Dataset
datastore = ws.get_default_datastore()
dataset = Dataset.Tabular.from_delimited_files(path=(datastore, 'datasets/training-data.csv'))
dataset.register(workspace=ws, name='training-data', create_new_version=True)
```

#### Validation
```python
from azureml.core import Workspace, Model, Dataset

ws = Workspace.from_config()

# Verify models
models = Model.list(ws)
print(f"Restored {len(models)} models")

# Verify datasets
datasets = Dataset.get_all(ws)
print(f"Restored {len(datasets)} datasets")

# Verify compute
from azureml.core.compute import ComputeTarget
compute_targets = ws.compute_targets
print(f"Restored {len(compute_targets)} compute targets")

# Test model deployment
from azureml.core.webservice import AciWebservice
service = Model.deploy(ws, "test-service", [models[0]], AciWebservice.deploy_configuration())
service.wait_for_deployment(show_output=True)
print(service.scoring_uri)
```

---

### 7.6 Data Recovery
**Scenario:** Accidental data deletion or corruption  
**RTO:** 1 hour | **RPO:** 1 hour  
**Trigger Criteria:** Critical data missing or corrupted

#### Procedure
```bash
# Step 1: Identify affected containers/blobs
az storage blob list --account-name st{env}{project}shared --container-name unity-catalog --auth-mode login

# Step 2: Check soft delete (14-day window)
az storage blob list --account-name st{env}{project}shared --container-name unity-catalog --include d --auth-mode login

# Step 3: Undelete soft-deleted blobs
az storage blob undelete --account-name st{env}{project}shared --container-name unity-catalog --name path/to/file.parquet --auth-mode login

# Step 4: If past soft delete, use point-in-time restore (7-day window)
az storage blob restore --account-name st{env}{project}shared \
  --time-to-restore "2025-01-15T14:00:00Z" \
  --blob-range unity-catalog/bronze unity-catalog/silver

# Step 5: If past 7 days, restore from GRS secondary
# This requires storage account failover (irreversible)
az storage account failover --name st{env}{project}shared --resource-group rg-{env}-{project}-shared --yes

# Step 6: If data corruption (not deletion), restore from Delta Lake time travel
databricks sql-query --sql "RESTORE TABLE dev_lob_team_1.bronze.sample_table TO VERSION AS OF 123" --profile prod

# Alternative: Restore to timestamp
databricks sql-query --sql "RESTORE TABLE dev_lob_team_1.bronze.sample_table TO TIMESTAMP AS OF '2025-01-15 14:00:00'" --profile prod
```

#### Validation
```bash
# Verify blob restored
az storage blob show --account-name st{env}{project}shared --container-name unity-catalog --name path/to/file.parquet --auth-mode login

# Verify Delta table restored
databricks sql-query --sql "DESCRIBE HISTORY dev_lob_team_1.bronze.sample_table" --profile prod

# Test data accessibility
databricks sql-query --sql "SELECT COUNT(*) FROM dev_lob_team_1.bronze.sample_table" --profile prod
```

---

### 7.7 Full Disaster Recovery
**Scenario:** Complete infrastructure loss (subscription deletion, ransomware)  
**RTO:** 8 hours | **RPO:** 24 hours  
**Trigger Criteria:** All resources inaccessible, multiple services down

#### Procedure
```bash
# Step 1: Create new Azure subscription (if needed)
az account create --offer-type "MS-AZR-0003P" --name "{project}-DR-Subscription"

# Step 2: Set up authentication
az login
az account set --subscription "{subscription-id}"

# Step 3: Clone infrastructure repository
git clone https://github.com/your-org/Azure-Databricks-AzureML.git
cd Azure-Databricks-AzureML

# Step 4: Configure Azure Developer CLI
azd init --environment prod-dr
azd auth login

# Step 5: Update environment parameters
# Edit .azure/prod-dr/.env
AZURE_LOCATION=canadacentral
AZURE_SUBSCRIPTION_ID={new-subscription-id}

# Step 6: Deploy full infrastructure
azd provision --environment prod-dr
# This deploys:
# - 4 resource groups
# - VNet, NSGs, private endpoints
# - Storage accounts (GRS)
# - Key Vault, ACR
# - Databricks workspace
# - Azure ML workspace
# - AI Foundry hub
# - Monitoring (Log Analytics, Application Insights)

# Step 7: Deploy Unity Catalog metastore and catalogs
cd terraform/metastore
terraform init
terraform apply -var-file=environments/prod-dr.tfvars

cd ../environments
terraform init
terraform apply -var-file=prod-dr.tfvars

# Step 8: Restore storage account data from GRS secondary
# (If primary account had GRS-RA - Read Access Geo-Redundant Storage)
# Data is automatically available in secondary region after failover

# Step 9: Restore Databricks workspace objects
./infra/scripts/restore-databricks-workspace.ps1 -Environment prod-dr -BackupDate "latest"

# Step 10: Restore Azure ML models and datasets
python scripts/restore-azureml-workspace.py --environment prod-dr --backup-date latest

# Step 11: Restore Key Vault secrets
# (Requires manual recreation or restoration from secure backup)
./infra/scripts/restore-keyvault-secrets.ps1 -Environment prod-dr

# Step 12: Update DNS/Application Gateway to point to new infrastructure
# (Manual step - depends on your DNS configuration)

# Step 13: Comprehensive validation
./infra/scripts/validate-deployment.ps1 -Environment prod-dr -ComprehensiveCheck
```

#### Validation
```bash
# 1. Verify all resource groups created
az group list --query "[?contains(name, 'prod-dr')].name" --output table

# 2. Verify resource count matches expected
az resource list --resource-group rg-prod-dr-{project}-shared | Measure-Object
az resource list --resource-group rg-prod-dr-{project}-databricks | Measure-Object
az resource list --resource-group rg-prod-dr-{project}-ai-platform | Measure-Object

# 3. Test Databricks connectivity
databricks workspace list --profile prod-dr
databricks clusters list --profile prod-dr

# 4. Test Unity Catalog
databricks unity-catalog catalogs list --profile prod-dr
databricks sql-query --sql "SHOW TABLES IN dev_lob_team_1.bronze" --profile prod-dr

# 5. Test Azure ML
az ml workspace show --name mlw-prod-dr-{project} --resource-group rg-prod-dr-{project}-ai-platform
az ml model list --workspace-name mlw-prod-dr-{project} --resource-group rg-prod-dr-{project}-ai-platform

# 6. Test storage account
az storage blob list --account-name stproddrsshared --container-name unity-catalog --auth-mode login

# 7. Test Key Vault
az keyvault secret list --vault-name kv-prod-dr-{project}

# 8. Run integration tests
pytest tests/integration/test_full_platform.py --env=prod-dr

# 9. Verify monitoring
az monitor log-analytics workspace show --resource-group rg-prod-dr-{project}-shared --workspace-name law-prod-dr-{project}

# 10. Test end-to-end workflow
# - Create Databricks notebook
# - Read data from Unity Catalog
# - Train Azure ML model
# - Deploy model to endpoint
# - Query model endpoint
```

---

## Validation & Testing

### 8.1 Disaster Recovery Testing Schedule
| **Test Type** | **Frequency** | **Scope** | **Owner** |
|---------------|---------------|-----------|-----------|
| **Tabletop Exercise** | Quarterly | Walk through runbook, no actual execution | Platform Team |
| **Storage Account Recovery** | Quarterly | Test soft delete and point-in-time restore | Platform Team |
| **Databricks Workspace Restore** | Bi-annually | Restore workspace from backup to test environment | Data Engineering |
| **Unity Catalog Restore** | Bi-annually | Restore metastore and catalogs | Data Engineering |
| **Azure ML Restore** | Bi-annually | Restore models and datasets | ML Engineering |
| **Full DR Failover** | Annually | Complete regional failover to secondary region | Platform + Engineering Teams |

### 8.2 DR Drill Procedure
```bash
# Quarterly DR Drill - Non-Disruptive
# Validates backup integrity without impacting production

# 1. Create isolated test resource group
az group create --name rg-dr-test-{date} --location canadacentral

# 2. Deploy test infrastructure
azd provision --environment dr-test

# 3. Restore backups to test environment
./infra/scripts/restore-databricks-workspace.ps1 -Environment dr-test -BackupDate "latest"

# 4. Validate restored data
pytest tests/dr/test_backup_integrity.py --env=dr-test

# 5. Document results
./infra/scripts/generate-dr-test-report.ps1 -Environment dr-test -OutputPath ./dr-test-reports/

# 6. Clean up test resources
az group delete --name rg-dr-test-{date} --yes --no-wait
```

### 8.3 Validation Scripts
Create automated validation scripts in `/infra/scripts/validate-dr-recovery.ps1`:

```powershell
# /infra/scripts/validate-dr-recovery.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$Environment,
    
    [switch]$ComprehensiveCheck
)

$ErrorActionPreference = "Stop"
$results = @()

# Test 1: Resource Group Existence
Write-Host "Validating resource groups..." -ForegroundColor Yellow
$expectedRGs = @(
    "rg-$Environment-{project}-shared",
    "rg-$Environment-{project}-databricks",
    "rg-$Environment-{project}-ai-platform",
    "rg-$Environment-{project}-compute"
)

foreach ($rg in $expectedRGs) {
    $exists = az group exists --name $rg
    $results += [PSCustomObject]@{
        Test = "Resource Group: $rg"
        Status = if ($exists -eq "true") { "PASS" } else { "FAIL" }
    }
}

# Test 2: Databricks Workspace Accessibility
Write-Host "Validating Databricks workspace..." -ForegroundColor Yellow
try {
    databricks workspace list --profile $Environment | Out-Null
    $results += [PSCustomObject]@{ Test = "Databricks Workspace API"; Status = "PASS" }
} catch {
    $results += [PSCustomObject]@{ Test = "Databricks Workspace API"; Status = "FAIL" }
}

# Test 3: Unity Catalog Availability
Write-Host "Validating Unity Catalog..." -ForegroundColor Yellow
try {
    $catalogs = databricks unity-catalog catalogs list --profile $Environment --output JSON | ConvertFrom-Json
    $results += [PSCustomObject]@{ Test = "Unity Catalog Catalogs ($($catalogs.Count) found)"; Status = "PASS" }
} catch {
    $results += [PSCustomObject]@{ Test = "Unity Catalog Catalogs"; Status = "FAIL" }
}

# Test 4: Storage Account Accessibility
Write-Host "Validating storage accounts..." -ForegroundColor Yellow
$storageAccounts = @("st${Environment}${project}shared", "st${Environment}${project}uc")
foreach ($sa in $storageAccounts) {
    try {
        az storage blob list --account-name $sa --container-name unity-catalog --auth-mode login --num-results 1 | Out-Null
        $results += [PSCustomObject]@{ Test = "Storage Account: $sa"; Status = "PASS" }
    } catch {
        $results += [PSCustomObject]@{ Test = "Storage Account: $sa"; Status = "FAIL" }
    }
}

# Test 5: Azure ML Workspace
Write-Host "Validating Azure ML workspace..." -ForegroundColor Yellow
try {
    az ml workspace show --name "mlw-$Environment-{project}" --resource-group "rg-$Environment-{project}-ai-platform" | Out-Null
    $results += [PSCustomObject]@{ Test = "Azure ML Workspace"; Status = "PASS" }
} catch {
    $results += [PSCustomObject]@{ Test = "Azure ML Workspace"; Status = "FAIL" }
}

# Test 6: Key Vault
Write-Host "Validating Key Vault..." -ForegroundColor Yellow
try {
    az keyvault secret list --vault-name "kv-$Environment-{project}" --query "[0]" | Out-Null
    $results += [PSCustomObject]@{ Test = "Key Vault Access"; Status = "PASS" }
} catch {
    $results += [PSCustomObject]@{ Test = "Key Vault Access"; Status = "FAIL" }
}

# Test 7: Private Endpoints (if comprehensive)
if ($ComprehensiveCheck) {
    Write-Host "Validating private endpoints..." -ForegroundColor Yellow
    $privateEndpoints = az network private-endpoint list --resource-group "rg-$Environment-{project}-shared" --query "[].name" -o tsv
    foreach ($pe in $privateEndpoints) {
        $status = az network private-endpoint show --name $pe --resource-group "rg-$Environment-{project}-shared" --query "provisioningState" -o tsv
        $results += [PSCustomObject]@{ Test = "Private Endpoint: $pe"; Status = if ($status -eq "Succeeded") { "PASS" } else { "FAIL" } }
    }
}

# Display results
Write-Host "`n========== DR Validation Results ==========" -ForegroundColor Cyan
$results | Format-Table -AutoSize

$failedTests = $results | Where-Object { $_.Status -eq "FAIL" }
if ($failedTests.Count -eq 0) {
    Write-Host "`nAll validation tests passed! ✓" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n$($failedTests.Count) validation tests failed! ✗" -ForegroundColor Red
    exit 1
}
```

---

## Contacts & Escalation

### 9.1 Incident Response Team
| **Role** | **Name** | **Email** | **Phone** | **Availability** |
|----------|----------|-----------|-----------|------------------|
| **Incident Commander** | [Name] | [email] | [phone] | 24/7 On-Call |
| **Platform Engineering Lead** | [Name] | [email] | [phone] | Business Hours |
| **Data Engineering Lead** | [Name] | [email] | [phone] | Business Hours |
| **ML Engineering Lead** | [Name] | [email] | [phone] | Business Hours |
| **Security Lead** | [Name] | [email] | [phone] | 24/7 On-Call |
| **Azure Support (Premier)** | Microsoft | [support-alias] | [phone] | 24/7 |

### 9.2 Escalation Path
```
Level 1: Platform Team (Primary Response)
  ├─> Level 2: Engineering Leads (If unresolved in 30 min)
      ├─> Level 3: Director of Engineering (If unresolved in 1 hour)
          ├─> Level 4: CTO / VP Engineering (Critical incidents)
              └─> Level 5: Microsoft Azure Support (Platform issues)
```

### 9.3 Communication Channels
- **Primary:** Microsoft Teams - #platform-incidents
- **Backup:** Slack - #data-platform-emergency
- **Escalation:** Email distribution list - platform-oncall@company.com
- **Status Page:** https://status.company.com/data-platform

### 9.4 External Support
- **Microsoft Azure Support Plan:** Premier Support (1-hour critical response SLA)
- **Databricks Support:** Standard Support (24/7)
- **Support Ticket Portals:**
  - Azure: https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade
  - Databricks: https://help.databricks.com

---

## Appendix

### A. Reference Architecture Diagram
![DR Architecture](./images/dr-architecture.png)

### B. Backup Inventory
**Storage Account:** `st{env}{project}shared`
```
backup-inventory/
├── unity-catalog-backups/
│   ├── 2025-01-14/
│   │   ├── metastore-backup.json
│   │   ├── catalogs-backup.json
│   │   └── schemas-*.json
│   └── 2025-01-15/
├── databricks-backups/
│   ├── 2025-01-14/
│   │   ├── notebooks/
│   │   ├── jobs-backup.json
│   │   └── policies-backup.json
│   └── 2025-01-15/
└── azureml-backups/
    ├── models/
    └── environments/
```

### C. Glossary
- **RTO (Recovery Time Objective):** Maximum acceptable downtime
- **RPO (Recovery Point Objective):** Maximum acceptable data loss
- **GRS (Geo-Redundant Storage):** Azure storage replication to secondary region
- **Soft Delete:** Azure feature allowing recovery of deleted resources
- **Unity Catalog:** Databricks data governance and metadata layer
- **Point-in-Time Restore:** Ability to restore storage to a specific timestamp

### D. Revision History
| **Version** | **Date** | **Author** | **Changes** |
|-------------|----------|------------|-------------|
| 1.0 | 2025-01-15 | Platform Team | Initial runbook creation |

### E. Related Documents
- [SECURITY-AUDIT.md](./SECURITY-AUDIT.md) - Security audit findings
- [DEPLOYMENT-PROCESS.md](./DEPLOYMENT-PROCESS.md) - Deployment procedures
- [TERRAFORM-AZD-INTEGRATION.md](./TERRAFORM-AZD-INTEGRATION.md) - Infrastructure details
- [PROJECT-STRUCTURE.md](./PROJECT-STRUCTURE.md) - Repository structure

---

**End of Disaster Recovery Runbook**

*This document is classified as Internal Use Only. Do not distribute outside the organization.*
