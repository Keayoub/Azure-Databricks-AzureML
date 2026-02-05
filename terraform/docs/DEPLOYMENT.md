# Terraform Unity Catalog Deployment Guide

This guide walks through deploying Databricks Unity Catalog using Terraform after the Bicep infrastructure is in place.

## Architecture Overview

```
Bicep Deployment
├── Resource Groups: Shared, Databricks, AI Platform, Compute
├── Networking: VNet, Subnets, NSGs, Private Endpoints
├── Databricks Workspace: dbw-dev-dbxaml (Premium tier with VNet injection)
├── Azure ML Workspace: aml-dev-dbxaml
├── AI Foundry Hub: aihub-dev-dbxaml
└── Storage: ADLS Gen2, Key Vault, Log Analytics

↓ Uses outputs from Bicep

Terraform Deployment (New)
├── UC Metastore: Storage Account + Access Connector
├── Catalogs: main, analytics (with schemas)
├── Schemas: raw, processed, reports, metrics
├── Volumes: External data containers
└── Access Control: RBAC and Grants via Terraform
```

## Prerequisites Checklist

Before deploying Terraform, ensure:

- [ ] Bicep deployment complete (`azd provision` succeeded)
- [ ] All 4 resource groups created:
  - [ ] `rg-dev-dbxaml-shared`
  - [ ] `rg-dev-dbxaml-databricks`
  - [ ] `rg-dev-dbxaml-ai-platform`
  - [ ] `rg-dev-dbxaml-compute`
- [ ] Databricks workspace deployed and accessible
- [ ] Azure CLI authenticated: `az login`
- [ ] Terraform installed: `terraform -v`
- [ ] AAD group created: `account_unity_admin` (or your metastore owner group)
- [ ] Databricks account ID obtained from account console

## Step 1: Gather Required Information

Get Databricks workspace details:

```bash
# List all Databricks workspaces
az databricks workspace list --query "[].{name: name, id: workspaceId}" -o table

# Get specific workspace info (replace workspace name)
WS_NAME="dbw-dev-dbxaml"
RG_NAME="rg-dev-dbxaml-databricks"

az databricks workspace show \
  -g "$RG_NAME" \
  -n "$WS_NAME" \
  --query "{workspace_id: workspaceId, workspace_url: workspaceUrl, subscription: id}" \
  -o json
```

Expected output:
```json
{
  "workspace_id": "2424101092929547",
  "workspace_url": "https://canadaeast.azuredatabricks.net",
  "subscription": "/subscriptions/c7b690b3-d9ad-4ed0-9942-4e7a36d0c187"
}
```

Get Databricks Account ID:

```bash
# Log in to https://accounts.azuredatabricks.net
# Account ID visible in Account Settings or click "Account" in top right
# Format: numeric string (e.g., "1234567890")
```

## Step 2: Configure Variables

Edit `terraform/environments/dev.tfvars`:

```hcl
subscription_id           = "c7b690b3-d9ad-4ed0-9942-4e7a36d0c187"  # Your subscription
azure_region              = "Canada East"
environment_name          = "dev"
project_name              = "dbxaml"
shared_resource_group_name = "rg-dev-dbxaml-shared"

# From workspace info above
databricks_workspace_id   = "2424101092929547"
databricks_workspace_host = "https://canadaeast.azuredatabricks.net"
databricks_account_id     = "1234567890"  # Replace with your account ID

metastore_owner = "account_unity_admin"  # AAD group name

# Catalog configuration
catalogs = {
  main = {
    name    = "main"
    comment = "Primary catalog"
    owner   = "account_unity_admin"
    schemas = {
      default = {
        name    = "default"
        comment = "Default schema"
        owner   = "account_unity_admin"
      }
      raw = {
        name    = "raw"
        comment = "Raw data ingestion"
        owner   = null
      }
      processed = {
        name    = "processed"
        comment = "Processed data"
        owner   = null
      }
    }
  }
  analytics = {
    name    = "analytics"
    comment = "Analytics catalog"
    owner   = "account_unity_admin"
    schemas = {
      reports = {
        name    = "reports"
        comment = "Report datasets"
      }
      metrics = {
        name    = "metrics"
        comment = "Metrics and KPIs"
      }
    }
  }
}

# Optional: Define external volumes
volumes = {}

tags = {
  project     = "databricks-azureml"
  environment = "dev"
  managed_by  = "terraform"
}
```

## Step 3: Verify Authentication

Test Azure CLI:
```bash
az account show --output json
```

Test Databricks workspace access:
```bash
# Will prompt for token if needed
databricks workspace list
```

## Step 4: Initialize Terraform

```bash
cd terraform/environments

# Initialize Terraform
terraform init

# This downloads providers and initializes state
# Expected output:
# - Terraform initialized
# - .terraform/ directory created
# - .terraform.lock.hcl created
```

## Step 5: Validate Configuration

```bash
# Check Terraform syntax
terraform validate

# Plan deployment (preview changes)
terraform plan -var-file=dev.tfvars

# Expected output:
# + module.uc_metastore.azurerm_storage_account.uc_metastore
# + module.uc_metastore.azurerm_storage_container.uc_metastore
# + module.uc_metastore.azurerm_databricks_access_connector.uc_connector
# + module.uc_metastore.databricks_metastore.primary
# ... (catalogs, schemas, etc)
```

## Step 6: Deploy in Stages

### Stage 1: Metastore (3-5 minutes)

Create the UC metastore first:

```bash
# Apply only the metastore module
terraform apply -var-file=dev.tfvars -target=module.uc_metastore
```

**Expected outputs:**
- Storage Account created: `stdbxamldevuc`
- Access Connector created: `ac-dbxaml-dev-uc`
- UC Metastore: `primary` created and assigned to workspace
- All RBAC roles assigned

**Verify:**
```bash
# Check metastore was created
terraform output metastore_id

# Verify in Databricks: Settings → Admin → Metastores
```

Wait 2-3 minutes for metastore to be fully initialized.

### Stage 2: Catalogs & Schemas (2-3 minutes)

```bash
# Apply catalog module
terraform apply -var-file=dev.tfvars -target=module.uc_catalogs
```

**Expected outputs:**
- Catalogs: `main`, `analytics` created
- Schemas: `default`, `raw`, `processed`, `reports`, `metrics` created
- Ownership grants applied

**Verify:**
```bash
# In Databricks UI:
# 1. Go to Catalog Explorer
# 2. Expand each catalog
# 3. Verify all schemas visible

# Or via CLI:
databricks catalogs list
databricks schemas list --catalog main
```

### Stage 3: Volumes (optional, 1-2 minutes)

If you have volumes defined:

```bash
# Apply volumes module
terraform apply -var-file=dev.tfvars -target=module.uc_volumes
```

### Stage 4: Full Synchronization

```bash
# Final apply to ensure everything is in sync
terraform apply -var-file=dev.tfvars
```

## Step 7: Verify Deployment

### Check Terraform State
```bash
# View all deployed resources
terraform state list

# Expected resources:
# module.uc_metastore.azurerm_storage_account.uc_metastore
# module.uc_metastore.databricks_metastore.primary
# module.uc_catalogs.databricks_catalog.this["main"]
# ... etc
```

### Verify in Databricks UI

1. **Workspace Settings:**
   - Go to Admin → Metastores
   - Verify "primary" metastore assigned
   - Check storage root: `abfss://uc-metastore@stdbxamldevuc.dfs.core.windows.net/`

2. **Catalog Explorer:**
   - Open Catalog Explorer
   - Verify catalogs: `main`, `analytics`
   - Expand each catalog
   - Verify schemas are visible

3. **Permissions:**
   - Click each catalog
   - Verify owner is "account_unity_admin"
   - Check ownership propagation to schemas

### Verify Storage Account

```bash
# Check storage account created
az storage account show -n stdbxamldevuc -g rg-dev-dbxaml-shared

# Verify container exists
az storage container list --account-name stdbxamldevuc

# Expected container: "uc-metastore"
```

### Verify Access Connector

```bash
# Check managed identity created
az databricks access-connector show \
  -g rg-dev-dev-dbxaml-shared \
  -n ac-dbxaml-dev-uc \
  --query identity
```

## Step 8: Configure Remote State (Optional)

For team collaboration, move state to Azure Storage:

1. **Create Terraform state container** (if not using Bicep storage):

```bash
# Use shared storage from Bicep
STORAGE_ACCOUNT="stdbxamldevq3a3hmrnwgh3m"  # From Bicep output
RESOURCE_GROUP="rg-dev-dbxaml-shared"

az storage container create \
  --account-name "$STORAGE_ACCOUNT" \
  --name terraform \
  --auth-mode key
```

2. **Update `terraform/environments/dev.tf`** - uncomment backend block:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-dev-dbxaml-shared"
    storage_account_name = "stdbxamldevq3a3hmrnwgh3m"
    container_name       = "terraform"
    key                  = "databricks-uc/terraform.tfstate"
  }
}
```

3. **Migrate state:**

```bash
terraform init -migrate-state
# Answer "yes" when prompted to migrate
```

## Troubleshooting

### Issue: "Workspace not found"
```
Error: azurerm_databricks_workspace.this not found
```
**Solution:**
- Verify workspace exists: `az databricks workspace show -g <RG> -n <WS_NAME>`
- Check spelling and resource group name
- Ensure workspace is in Premium tier

### Issue: "Authentication failed"
```
Error: Error building AzureRM Client: authorization.RoleAssignments.CreateFunc
```
**Solution:**
```bash
# Re-authenticate
az logout
az login

# Verify role
az role assignment list --assignee $(az account show --query user.name -o tsv)
# Must have Contributor or Owner role
```

### Issue: "Databricks provider error"
```
Error: authentication error: Invalid personal API token
```
**Solution:**
- Delete Databricks config: `rm ~/.databrickscfg`
- Re-authenticate: `databricks configure --token`
- Or use Azure CLI auth: set `auth_type = "azure-cli"` in provider

### Issue: "Metastore quota exceeded"
```
Error: Cannot create metastore: Metastore quota exceeded
```
**Solution:**
- Only one metastore per region
- Check if one already exists: `terraform state list | grep metastore`
- Or destroy and recreate: `terraform destroy -target=module.uc_metastore`

### Issue: "Workspace already has metastore"
```
Error: Workspace already assigned to metastore
```
**Solution:**
```bash
# Check current assignment
databricks workspace get-status --workspace-id <ID>

# If needed, manually detach via Databricks UI first
# Or import existing metastore:
terraform import module.uc_metastore.databricks_metastore.primary <METASTORE_ID>
```

## Post-Deployment Steps

### 1. Create AAD Groups for Data Teams

```bash
# Create groups in Azure AD
az ad group create --display-name "data-engineers"
az ad group create --display-name "data-analysts"
az ad group create --display-name "data-scientists"
```

### 2. Add Team Catalogs

Edit `dev.tfvars` to add team-specific catalogs:

```hcl
catalogs = {
  main = { ... },
  analytics = { ... },
  data_engineering = {
    name    = "data_engineering"
    comment = "Data Engineering team catalog"
    owner   = "data-engineers"  # AAD group
    schemas = {
      pipelines = {
        name    = "pipelines"
        comment = "ETL pipelines"
      }
      staging = {
        name    = "staging"
        comment = "Staging area"
      }
    }
  }
}
```

Apply changes:
```bash
terraform apply -var-file=dev.tfvars
```

### 3. Create External Locations

For accessing data outside Databricks (optional):

```bash
# Define in dev.tfvars or create separate Terraform module
# Example: Attach ADLS storage for external tables
```

### 4. Set Up Unity Catalog Audit Logging

Monitor UC operations:

```bash
# Check audit logs in Databricks workspace:
# Admin → Audit Logs
# Filter by: UC metastore operations
```

### 5. Test UC Access

```bash
# In Databricks notebook
%sql
SHOW CATALOGS;
SHOW SCHEMAS IN CATALOG main;

-- Create test table
CREATE TABLE main.default.test_table (id INT, name STRING);
INSERT INTO main.default.test_table VALUES (1, 'test');
SELECT * FROM main.default.test_table;
```

## Maintenance & Updates

### Add New Catalog

1. Edit `dev.tfvars`
2. Add catalog definition
3. Run:
   ```bash
   terraform plan -var-file=dev.tfvars
   terraform apply -var-file=dev.tfvars
   ```

### Update Ownership

Edit `dev.tfvars`:
```hcl
catalogs = {
  main = {
    ...
    owner = "new-owner-group"  # Change this
    ...
  }
}
```

Apply:
```bash
terraform apply -var-file=dev.tfvars
```

### Destroy UC Infrastructure

**WARNING: This destroys all UC configuration!**

```bash
# Preview destruction
terraform plan -destroy -var-file=dev.tfvars

# Destroy
terraform destroy -var-file=dev.tfvars
```

## Next Steps

1. **Integrate with data pipelines** - Use Unity Catalog in your ETL/ELT workflows
2. **Set up Delta Live Tables** - For automated data governance
3. **Configure external locations** - For cloud storage (S3, ADLS, GCS)
4. **Implement data quality rules** - Using Databricks expectations
5. **Enable table optimization** - For better query performance
6. **Set up lineage tracking** - Monitor data flow across organization

## References

- [Terraform Databricks Provider Docs](https://registry.terraform.io/providers/databricks/databricks/latest/docs)
- [Databricks Unity Catalog Guide](https://docs.databricks.com/en/data-governance/unity-catalog/index.html)
- [Azure Terraform Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
