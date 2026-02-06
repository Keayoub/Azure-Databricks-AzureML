# Deployment Process

This document describes the two-phase deployment architecture for this project.

## Architecture Overview

The deployment is split into two phases:

1. **Phase 1: Infrastructure (Bicep)** - Azure resources and Databricks workspace
2. **Phase 2: Configuration (Terraform)** - Unity Catalog metadata and components

### Why Two Phases?

- **Bicep** handles Azure infrastructure (network, storage, Databricks workspace)
- **Terraform** handles Databricks account-level configuration (metastore, catalogs, schemas)
- Separation ensures clear ownership: Azure ops vs. Databricks admins

---

## Phase 1: Infrastructure Deployment

### What Gets Created

- Resource Groups (4 total): Shared, Databricks, AI Platform, Compute
- Virtual Network with subnets and NSGs
- Azure Databricks workspace (Premium, VNet-injected)
- Azure Storage Account (ADLS Gen2) for Unity Catalog
- Access Connector for Databricks
- Azure ML workspace and AI Foundry hub
- Key Vault, Container Registry, monitoring resources
- Private endpoints for all data services

### How to Run

```powershell
# 1. Validate prerequisites
pwsh infra/scripts/validate.ps1

# 2. Deploy infrastructure (includes postprovision hook)
azd provision

# This automatically runs after Bicep completes:
# - infra/scripts/postprovision.ps1 → Creates Unity Catalog metastore
```

### What postprovision.ps1 Does

Located in `infra/scripts/postprovision.ps1`, this script:

1. Retrieves Bicep deployment outputs (storage, workspace URL, resource groups)
2. Extracts workspace ID and region from Bicep outputs
3. Generates `terraform/metastore/terraform.tfvars`
4. Runs `terraform apply` to create the metastore:
   - Creates `metastore-${projectName}` (one per region)
   - Configures managed identity access via Access Connector
   - Assigns metastore to workspace

**Postprovision is idempotent**: Safe to run multiple times. If metastore exists, it skips creation and just attaches the workspace.

---

## Phase 2: Configuration Deployment

### What Gets Created

- Unity Catalog catalogs (e.g., `dev_lob_team_1`, `prod_lob_team_1`)
- Schemas (bronze, silver, gold medallion architecture)
- External volumes and delta sharing objects
- Storage credentials for external locations

### How to Run

```powershell
# Deploy UC catalogs and schemas
azd deploy

# This runs postdeploy hook:
# - infra/scripts/postdeploy.ps1 → Deploys Terraform UC components
```

### What postdeploy.ps1 Does

Located in `infra/scripts/postdeploy.ps1`, this script:

1. Initializes Terraform in `terraform/environments/`
2. Plans and applies UC component configuration
3. Creates catalogs, schemas, and volumes

---

## Complete Deployment Flow (azd)

```
┌─────────────────────────────────────────────────────┐
│ azd provision                                       │
├─────────────────────────────────────────────────────┤
│ 1. Deploy Bicep (main.bicep)                        │
│    → Creates Azure resources                        │
│                                                     │
│ 2. Postprovision hook (automatic)                   │
│    → Runs infra/scripts/postprovision.ps1           │
│    → Creates Databricks metastore                   │
│    → Assigns workspace to metastore                 │
└─────────────────────────────────────────────────────┘
                        ↓
                 (Metastore ready)
                        ↓
┌─────────────────────────────────────────────────────┐
│ azd deploy                                          │
├─────────────────────────────────────────────────────┤
│ 1. Postdeploy hook (automatic)                      │
│    → Runs infra/scripts/postdeploy.ps1              │
│    → Deploys Terraform (terraform/environments/)    │
│    → Creates catalogs, schemas, volumes             │
└─────────────────────────────────────────────────────┘
```

---

## Manual Phase Execution

If you need to run phases separately:

### Phase 1 Only

```powershell
# Validate prerequisites
pwsh infra/scripts/validate.ps1

# Deploy Bicep infrastructure
azd provision
```

### Phase 2 Only (After Phase 1)

```powershell
# Deploy UC components
pwsh infra/scripts/postdeploy.ps1
```

Or manually:

```powershell
cd terraform/environments
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

---

## Terraform State Management

Both Terraform layers store state in Azure Storage:

```
Resource Group: rg-dev-dbxaml-shared
Storage Account: stdbxamldevq3a3hmrnwgh3m
Container: tfstate

Files:
  - metastore.tfstate    (Metastore backend)
  - environments.tfstate (UC components backend)
```

### Initialize Backend (One-Time)

If the backend container doesn't exist:

```powershell
# Create storage container for Terraform state
az storage container create \
  --account-name stdbxamldevq3a3hmrnwgh3m \
  --name tfstate \
  --resource-group rg-dev-dbxaml-shared
```

---

## Troubleshooting

### Postprovision Failed

Check error logs:

```powershell
cd terraform/metastore
terraform plan
terraform apply
```

Common issues:
- **Missing DATABRICKS_ACCOUNT_ID**: Set environment variable
- **Access Connector not found**: Verify Bicep deployed successfully
- **Region not recognized**: Check Databricks account regional availability

### Postdeploy Failed

Check error logs:

```powershell
cd terraform/environments
terraform validate
terraform plan
terraform apply
```

Common issues:
- **Metastore not assigned**: Run postprovision first
- **Invalid catalog names**: Check `terraform.tfvars` for special characters
- **Permission denied**: Verify workspace admin permissions in Databricks

### Rerun Deployment

To rerun the entire deployment:

```powershell
# Clean up and rerun
cd infra
azd provision --fresh

# Then deploy UC components
azd deploy
```

---

## Best Practices

1. **Always validate before deploying**
   ```powershell
   pwsh infra/scripts/validate.ps1
   ```

2. **Review plans before applying**
   ```powershell
   terraform plan -out=tfplan  # Review first
   terraform apply tfplan       # Then apply
   ```

3. **Keep state files backed up**
   - State is stored in Azure Storage (versioned, encrypted)
   - Local tfplan files are temporary and can be deleted

4. **Use environment-specific tfvars**
   - If deploying to multiple environments, create separate tfvars files
   - Example: `terraform/environments/dev.tfvars`, `prod.tfvars`

5. **Document changes**
   - Always commit Terraform code changes to version control
   - Generated `terraform.tfvars` files should NOT be committed

---

## Next Steps

1. ✅ Deploy infrastructure with `azd provision`
2. ✅ Deploy UC components with `azd deploy`
3. 📚 Review [TERRAFORM-QUICK-REFERENCE.md](../terraform/docs/TERRAFORM-QUICK-REFERENCE.md) for resource details
4. 🔐 Configure Unity Catalog permissions in Databricks workspace
5. 📊 Create catalogs, schemas, and tables as needed

For detailed Terraform configuration, see [terraform/README.md](../terraform/README.md).
