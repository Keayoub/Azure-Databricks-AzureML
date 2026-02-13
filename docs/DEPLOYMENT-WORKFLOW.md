# Deployment Workflow

## Two-Phase Terraform Deployment

This project uses a **two-phase Terraform approach** to separate infrastructure provisioning from Unity Catalog component deployment.

### Architecture

```
azd provision                     azd deploy
    ↓                                 ↓
┌─────────────┐               ┌─────────────┐
│   Bicep     │               │   Nothing   │
│  (Azure     │               │  (Skip      │
│   Infra)    │               │   Bicep)    │
└──────┬──────┘               └─────────────┘
       │                               │
       ↓                               ↓
┌─────────────┐               ┌─────────────┐
│ Terraform   │               │ Terraform   │
│ (Metastore) │               │ (UC Cats/   │
│             │               │  Schemas)   │
└─────────────┘               └─────────────┘
```

---

## Phase 1: Infrastructure Provisioning (`azd provision`)

### What Happens
1. **Bicep Deployment**: Creates all Azure infrastructure
   - Resource Groups (Network, Shared, Databricks, Compute)
   - Virtual Network with private subnets
   - Azure Databricks workspace (Premium, VNet-injected)
   - Storage accounts (ADLS Gen2 with HNS enabled)
   - Access Connector for Unity Catalog
   - Key Vault, Azure ML, AI Foundry
   - Private endpoints

   Key Vault patterns and Databricks secret scope guidance:
   [DATABRICKS-KEYVAULT-ARCHITECTURE-GUIDE.md](DATABRICKS-KEYVAULT-ARCHITECTURE-GUIDE.md)

2. **Terraform Metastore** (via `postprovision` hook):
   - Checks if metastore exists in region
   - Creates metastore if doesn't exist (or references existing)
   - Configures data access with managed identity
   - Assigns metastore to workspace

### Commands
```powershell
# Full provisioning (Bicep + Metastore)
azd provision

# Manual metastore Terraform only
cd terraform/metastore
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### Script: `infra/scripts/postprovision.ps1`
- Runs automatically after Bicep deployment
- Navigates to `terraform/metastore/`
- Generates `terraform.tfvars` from Bicep outputs
- Executes: `terraform init → plan → apply`

### Outputs
- Metastore created/referenced
- Metastore assigned to workspace
- Ready for UC component deployment

---

## Phase 2: Unity Catalog Components (`azd deploy`)

### What Happens
1. **Bicep Deployment**: Skipped (no changes)

2. **Terraform UC Components** (via `postdeploy` hook):
   - References existing metastore
   - Creates catalogs (dev, qa, prod)
   - Creates schemas (bronze, silver, gold)
   - Creates external volumes

### Commands
```powershell
# Full deployment (Bicep skip + UC components)
azd deploy

# Manual UC Terraform only
cd terraform/environments
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### Script: `infra/scripts/postdeploy.ps1`
- Runs automatically after Bicep (no-op)
- Navigates to `terraform/environments/`
- Generates minimal `terraform.tfvars` (only workspace URL)
- Executes: `terraform init → plan → apply`

### Outputs
- Catalogs created: `dev_lob_team_1`, `qa_lob_team_1`, `prod_lob_team_1`
- Schemas created: `bronze`, `silver`, `gold`
- External volumes created
- Unity Catalog ready for use

---

## Why Two Phases?

### Benefits
1. **Idempotency**: Metastore created once per region, not recreated on every deploy
2. **Separation of Concerns**: Infrastructure vs. logical UC objects
3. **Faster Deployments**: `azd deploy` only updates UC catalogs/schemas
4. **Manual Metastore Option**: Can create metastore via UI, skip Terraform metastore layer
5. **No State Conflicts**: Metastore state separate from UC components state

### Alternative: Manual Metastore Creation
If you prefer to create the metastore manually:
1. Create metastore via Databricks Account Console UI
2. Skip `terraform/metastore` execution
3. Run only `terraform/environments` (UC components)

---

## Hook Configuration (`azure.yaml`)

```yaml
hooks:
  postprovision:
    shell: pwsh
    run: ./infra/scripts/postprovision.ps1  # Metastore layer
  
  postdeploy:
    shell: pwsh
    run: ./infra/scripts/postdeploy.ps1      # UC components
```

---

## Terraform Directory Structure

```
terraform/
├── metastore/           # Phase 1: Metastore creation (azd provision)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars (auto-generated)
│
└── environments/        # Phase 2: UC components (azd deploy)
    ├── main.tf
    ├── providers.tf
    ├── variables.tf
    ├── outputs.tf
    └── terraform.tfvars (auto-generated)
```

---

## Troubleshooting

### "Metastore limit reached"
- Only 1 metastore allowed per region per account
- Terraform automatically detects and uses existing metastore
- If manual deletion needed: Databricks Account Console → Data → Metastores

### "Unauthorized network access"
- Workspace has `publicNetworkAccess = 'Disabled'`
- Solution: Deploy Bastion + Jumpbox, run Terraform from jumpbox
- Or: Temporarily enable public access in `infra/components/databricks/databricks.bicep`

### "Terraform state out of sync"
- Metastore state: `terraform/metastore/terraform.tfstate`
- UC components state: `terraform/environments/terraform.tfstate`
- Separate states prevent conflicts

---

## Best Practices

1. **Always use azd commands**: `azd provision` and `azd deploy`
2. **Don't modify Terraform directly** unless debugging
3. **Check Bicep outputs** if Terraform fails (missing env vars)
4. **Use Bastion/Jumpbox** for secure deployments
5. **Lock down public access** after initial setup

---

## Workflow Summary

| Command        | Bicep | Terraform Metastore | Terraform UC Components |
|----------------|-------|---------------------|-------------------------|
| `azd provision`| ✅     | ✅                   | ❌                       |
| `azd deploy`   | ⏭️     | ❌                   | ✅                       |

Legend: ✅ Runs | ❌ Skips | ⏭️ No changes
