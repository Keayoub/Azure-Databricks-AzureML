# Terraform + azd Integration Guide

## Overview

This project uses a two-stage deployment approach:

1. **Bicep Phase** (`azd provision`): Deploys Azure infrastructure
   - Virtual Networks, Subnets, Network Security Groups
   - Azure Databricks workspace (Premium, VNet-injected)
   - Storage accounts, Key Vault, monitoring resources
   - Cross-RG RBAC assignments

2. **Terraform Phase** (automatic post-Bicep): Deploys Unity Catalog layer
   - UC metastore infrastructure
   - Catalogs, schemas, and volumes
   - External locations and storage credentials
   - RBAC grants for UC resources

## Deployment Flow

```
azd provision
    ↓
┌─────────────────────────────┐
│ Phase 1: Bicep Deployment   │
├─────────────────────────────┤
│ • Resource Groups           │
│ • Networking                │
│ • Databricks Workspace      │
│ • Storage & Monitoring      │
│ • RBAC Assignments          │
└─────────────────────────────┘
    ↓ (postprovision hook)
┌─────────────────────────────┐
│ Phase 2: Terraform Deploy   │
├─────────────────────────────┤
│ • UC Metastore              │
│ • Storage Credentials       │
│ • Catalogs & Schemas        │
│ • External Locations        │
│ • UC Permissions            │
└─────────────────────────────┘
    ↓
✓ Complete Databricks Lakehouse
```

## How to Deploy

### Prerequisites

```bash
# 1. Install Azure CLI and azd
winget install azure-cli
winget install azd

# 2. Set Databricks Account ID (required for UC provisioning)
$env:DATABRICKS_ACCOUNT_ID = "your-account-id"

# 3. Install Terraform (for post-provision phase)
winget install hashicorp.terraform
```

### Single Command Deployment

```bash
cd d:\Databricks\dbx-demos\Azure-Databricks-AzureML

# Deploy everything: Bicep + Terraform UC
azd provision
```

**What happens:**
1. azd deploys Bicep infrastructure (3-5 minutes)
2. Automatically runs postprovision.sh hook
3. Terraform initializes and deploys UC layer (2-3 minutes)
4. Full Databricks Lakehouse ready to use

### Manual Terraform Deployment (after Bicep)

If you want to run Terraform separately:

```bash
cd terraform

# Create variables file
cat > terraform.tfvars <<EOF
subscription_id                = "your-subscription-id"
azure_region                   = "Canada East"
environment_name               = "dev"
project_name                   = "databricks"
shared_resource_group_name     = "your-resource-group"
databricks_workspace_id        = "your-workspace-id"
databricks_workspace_host      = "https://your-workspace.canadaeast.azuredatabricks.net"
databricks_account_id          = "your-account-id"
metastore_storage_name         = "adbmetastore123"
metastore_name                 = "uc_metastore_dev"
access_connector_name          = "adb-access-connector"
EOF

# Deploy
terraform init
terraform plan
terraform apply
```

## Output Mapping: Bicep → Terraform

The postprovision script automatically captures Bicep outputs and feeds them into Terraform:

| Bicep Output | Terraform Variable | Used For |
|---|---|---|
| Resource Group Name | `shared_resource_group_name` | Storage account location |
| Workspace ID | `databricks_workspace_id` | UC assignment |
| Workspace URL | `databricks_workspace_host` | Databricks provider config |
| Azure Region | `azure_region` | All resources |

The script queries Azure using:
```bash
# Get workspace details from Bicep-deployed RG
az resource list --resource-group "$RESOURCE_GROUP" \
  --resource-type "Microsoft.Databricks/workspaces" \
  --query "[0]" -o json
```

## Environment Variables

Set these before running `azd provision`:

```bash
# Required
export DATABRICKS_ACCOUNT_ID="your-databricks-account-id"

# Optional (defaults to dev if not set)
export ENVIRONMENT_NAME="dev"      # dev, staging, prod
export PROJECT_NAME="databricks"

# Azure authentication (azd handles this via `az login`)
```

## Module Structure

### Terraform Modules (GitHub-style)

```
terraform/
├── modules/
│   ├── adb-uc-metastore/        # UC metastore + Access Connector
│   │   ├── versions.tf
│   │   ├── variables.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   │
│   ├── adb-uc-catalogs/         # Catalogs, schemas, volumes
│   │   ├── versions.tf
│   │   ├── variables.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   │
│   └── adb-uc-volumes/          # External locations & volumes
│       ├── versions.tf
│       ├── variables.tf
│       ├── main.tf
│       ├── outputs.tf
│       └── README.md
│
├── environments/
│   ├── dev.tfvars               # Dev configuration
│   ├── main.tf                  # Module composition
│   ├── variables.tf             # Input variables
│   ├── outputs.tf               # Root outputs
│   └── providers.tf             # Provider config
│
└── README.md
```

### Bicep Structure

```
infra/
├── main.bicep                   # Root module (subscription scope)
├── main.bicepparam              # Parameters
├── components/
│   ├── databricks/              # Workspace, VNet injection
│   ├── storage/                 # Data lake, metastore storage
│   ├── networking/              # VNets, subnets, NSGs
│   ├── monitoring/              # Log Analytics, diagnostics
│   ├── keyvault/                # Secrets, credentials
│   ├── security/                # RBAC assignments
│   └── ...other components
│
└── scripts/
    ├── postprovision.sh         # Terraform deployment hook
    └── deployment/
        └── install-prerequisites.ps1
```

## Troubleshooting

### Issue: "DATABRICKS_ACCOUNT_ID not set"

**Solution:**
```bash
$env:DATABRICKS_ACCOUNT_ID = "your-account-id"
```

### Issue: Terraform plan fails with "workspace not found"

**Solution:** Ensure Bicep deployment completed successfully:
```bash
# Check workspace exists
az resource list --resource-group "your-rg" \
  --resource-type "Microsoft.Databricks/workspaces"
```

### Issue: UC metastore creation fails with auth error

**Solution:** Verify Databricks provider authentication:
```bash
# Check token/auth
export DATABRICKS_HOST="https://accounts.azuredatabricks.net"
export DATABRICKS_ACCOUNT_ID="your-account-id"
# Use service principal or user token
```

### Issue: Storage account RBAC fails

**Solution:** Ensure managed identity from Access Connector has permissions:
```bash
# Verify access connector was created
az resource list --resource-group "your-rg" \
  --resource-type "Microsoft.Databricks/accessConnectors"
```

## Cleanup

To remove all resources:

```bash
cd terraform
terraform destroy

cd ..
azd down  # Removes Bicep-deployed resources
```

## Next Steps

After deployment:

1. **Configure storage credentials** in Databricks for each external location
2. **Assign catalog grants** to teams/groups
3. **Set up data ingestion** pipelines to bronze catalog
4. **Configure Unity Catalog policies** for data governance
5. **Enable audit logging** for compliance

## References

- [Terraform Databricks Provider](https://registry.terraform.io/providers/databricks/databricks/latest)
- [Azure Developer CLI](https://learn.microsoft.com/azure-dev/overview)
- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Databricks Unity Catalog](https://docs.databricks.com/en/data-governance/unity-catalog/)
