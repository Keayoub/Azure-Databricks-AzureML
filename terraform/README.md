# Databricks Unity Catalog - Terraform Implementation

Complete Terraform configuration for provisioning Databricks Unity Catalog infrastructure on Azure.

## Quick Start

### 1. Prerequisites

```bash
# Ensure Bicep deployment completed
az resource list --resource-group "your-rg" \
  --resource-type "Microsoft.Databricks/workspaces"
```

### 2. Deploy with azd (Recommended)

```bash
# Set environment variable
export DATABRICKS_ACCOUNT_ID="your-account-id"

# Deploy Bicep + Terraform in one command
cd d:\Databricks\dbx-demos\Azure-Databricks-AzureML
azd provision
```

This automatically:
1. Deploys Bicep infrastructure (networking, workspace, storage)
2. Runs postdeploy hook that deploys Terraform UC layer
3. Creates complete Databricks Lakehouse

See [TERRAFORM-AZD-INTEGRATION.md](../docs/TERRAFORM-AZD-INTEGRATION.md) for details.

### 3. Or Deploy Terraform Manually

```bash
cd terraform

# Create terraform.tfvars (populate from Bicep outputs)
cat > terraform.tfvars <<EOF
subscription_id                = "your-subscription-id"
azure_region                   = "Canada East"
environment_name               = "dev"
project_name                   = "databricks"
shared_resource_group_name     = "your-rg"
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

## Architecture

```
Azure Infrastructure (Bicep)
├── Resource Groups
│   ├── Shared (networking, storage, monitoring)
│   ├── Databricks (workspace, managed resources)
│   ├── AI Platform (Azure ML, AI Foundry)
│   └── Compute (AKS, containers)
└── Databricks Workspace (dbw-dev-dbxaml)

Databricks Unity Catalog (Terraform) ← You are here
├── UC Metastore (primary)
│   ├── Storage Account (ADLS Gen2)
│   ├── Access Connector (Managed Identity)
│   └── Metastore Configuration
├── Catalogs & Schemas
│   ├── main (default)
│   │   ├── default
│   │   ├── raw
│   │   └── processed
│   └── analytics
│       ├── reports
│       └── metrics
└── Volumes (External Data Storage)
```

## Prerequisites

1. **Azure Setup:**
   - Azure CLI installed and authenticated: `az login`
   - Subscription ID and resource groups created (from Bicep deployment)
   
2. **Terraform Setup:**
   - Terraform v1.3+
   - Azure Provider v3.70+
   - Databricks Provider v1.30+

3. **Databricks Setup:**
   - Workspace deployed (from Bicep)
   - Account ID (from Databricks account console)
   - AAD groups created in Databricks (e.g., `account_unity_admin`)

4. **Information from Bicep Deployment:**
   - Shared resource group name: `rg-dev-dbxaml-shared`
   - Databricks workspace ID: Get from `az databricks workspace show`
   - Databricks workspace URL: Get from workspace UI
   - Databricks account ID: From account console

## Getting Started

### Step 1: Update Configuration

Edit `terraform/environments/dev.tfvars` with your environment details:

```hcl
subscription_id           = "YOUR_SUBSCRIPTION_ID"
databricks_workspace_id   = "YOUR_WORKSPACE_ID"    # From workspace info
databricks_workspace_host = "https://region.azuredatabricks.net"
databricks_account_id     = "YOUR_ACCOUNT_ID"      # From account console
```

### Step 2: Get Workspace Information

```bash
# List workspaces
az databricks workspace list -g rg-dev-dbxaml-databricks -o table

# Get specific workspace details
az databricks workspace show \
  -g rg-dev-dbxaml-databricks \
  -n dbw-dev-dbxaml \
  --query '{workspace_id: workspaceId, workspace_url: workspaceUrl}'
```

### Step 3: Configure Databricks Provider

The Terraform configuration uses Azure CLI authentication:

```bash
# Ensure you're logged in with the right Azure account
az account show

# Verify Databricks workspace access
az rest -m post -u "https://{workspace_url}/api/2.0/workspace/list" \
  -H "Content-Type: application/json" -d "{}"
```

### Step 4: Initialize Terraform

```bash
cd terraform/environments

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan -var-file=dev.tfvars
```

### Step 5: Deploy UC Infrastructure

```bash
# Apply configuration
terraform apply -var-file=dev.tfvars

# Save outputs
terraform output -json > ../outputs.json
```

## Module Structure

### 1. `databricks-uc-metastore`

Creates the UC metastore infrastructure on Azure:

**Resources:**
- Azure Storage Account (ADLS Gen2) - for UC metadata storage
- Storage Container - for metastore root
- Databricks Access Connector - Managed Identity for secure access
- UC Metastore - Primary metastore for workspace
- Metastore Data Access - Credentials configuration
- Metastore Assignment - Binds metastore to workspace

**Variables:**
- `subscription_id` - Azure subscription
- `resource_group_name` - RG for UC resources
- `location` - Azure region
- `databricks_workspace_id` - Workspace to attach metastore
- `databricks_account_id` - For account-level operations
- `metastore_owner` - Principal (AAD group) owning metastore

**Outputs:**
- `metastore_id` - UC metastore ID
- `storage_account_id` - Backing storage account
- `access_connector_id` - Managed Identity connector

### 2. `databricks-uc-catalogs`

Creates UC catalogs and schemas:

**Resources:**
- Catalogs - Organizational containers
- Schemas - Collections within catalogs
- Grants - Ownership and permissions

**Variables:**
- `metastore_id` - Parent metastore
- `catalogs` - Map of catalog definitions with nested schemas

**Configuration Example:**
```hcl
catalogs = {
  main = {
    name    = "main"
    comment = "Production catalog"
    owner   = "account_unity_admin"
    schemas = {
      raw = {
        name    = "raw"
        comment = "Raw data layer"
        owner   = null
      }
      processed = {
        name    = "processed"
        comment = "Processed data"
        owner   = null
      }
    }
  }
}
```

### 3. `databricks-uc-volumes`

Creates UC volumes for external data:

**Resources:**
- Volumes - External storage locations
- Grants - Volume permissions

**Variables:**
- `volumes` - Map of volume definitions

**Configuration Example:**
```hcl
volumes = {
  raw_data = {
    catalog_name = "main"
    schema_name  = "raw"
    name         = "raw-data"
    comment      = "External data ingestion"
    owner        = null
  }
}
```

## Deployment Workflow

### First Time Setup

```bash
# 1. Initialize and validate
cd terraform/environments
terraform init
terraform validate

# 2. Preview changes
terraform plan -var-file=dev.tfvars

# 3. Create metastore
terraform apply -var-file=dev.tfvars -target=module.uc_metastore

# 4. Wait for metastore to be ready (~2 minutes)

# 5. Create catalogs and schemas
terraform apply -var-file=dev.tfvars -target=module.uc_catalogs

# 6. Create volumes
terraform apply -var-file=dev.tfvars -target=module.uc_volumes

# 7. Final apply to ensure everything is in sync
terraform apply -var-file=dev.tfvars
```

### Subsequent Updates

```bash
# Plan changes
terraform plan -var-file=dev.tfvars -out=tfplan

# Review and apply
terraform apply tfplan
```

## State Management

### Local State (Development)
Default configuration - state stored locally in `.terraform/`

### Remote State (Recommended)

Uncomment the backend block in `environments/dev.tf`:

```hcl
backend "azurerm" {
  resource_group_name  = "rg-dev-dbxaml-shared"
  storage_account_name = "stdbxamldevq3a3hmrnwgh3m"  # From Bicep output
  container_name       = "terraform"
  key                  = "databricks-uc/terraform.tfstate"
}
```

Then migrate state:

```bash
terraform init -migrate-state
```

## Common Operations

### Add New Catalog

Edit `dev.tfvars`:

```hcl
catalogs = {
  # ... existing catalogs ...
  new_catalog = {
    name    = "new_catalog"
    comment = "New catalog for new team"
    owner   = "new_team_admin"
    schemas = {
      datasets = {
        name    = "datasets"
        comment = "Team datasets"
      }
    }
  }
}
```

Apply:

```bash
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

### Create External Volume

Edit `dev.tfvars`:

```hcl
volumes = {
  team_data = {
    catalog_name = "new_catalog"
    schema_name  = "datasets"
    name         = "team-data"
    comment      = "Team external data volume"
    owner        = "new_team_admin"
  }
}
```

### Grant Permissions

To grant permissions on catalogs/schemas, update the `owner` field or use Databricks workspace UI.

### Destroy UC Infrastructure

```bash
# WARNING: This will delete all UC data governance
terraform destroy -var-file=dev.tfvars
```

## Integration with Bicep

### Required Outputs from Bicep

Ensure Bicep deployment provides:
1. Shared resource group name
2. Databricks workspace ID
3. Databricks workspace URL
4. Storage account name (for remote state)

### Configuration Pass-Through

Values from Bicep deployment should be:
1. Stored as environment variables or
2. Passed via tfvars file or
3. Configured in `dev.tfvars` manually

Example getting values from Bicep:

```bash
#!/bin/bash
RG_NAME="rg-dev-dbxaml-shared"
WS_NAME="dbw-dev-dbxaml"

WS_ID=$(az databricks workspace show \
  -g rg-dev-dbxaml-databricks \
  -n "$WS_NAME" \
  --query workspaceId -o tsv)

WS_URL=$(az databricks workspace show \
  -g rg-dev-dbxaml-databricks \
  -n "$WS_NAME" \
  --query workspaceUrl -o tsv)

echo "Workspace ID: $WS_ID"
echo "Workspace URL: $WS_URL"
```

## Troubleshooting

### Error: "Workspace not found"
- Verify workspace name and resource group
- Check resource group exists: `az group show -n rg-dev-dbxaml-databricks`

### Error: "Missing required attribute"
- Check all required variables are set in `dev.tfvars`
- Verify module variable definitions match

### Error: "Account ID not valid"
- Account ID format: numeric string (e.g., "1234567890")
- Get from: Databricks Account Console → Account Settings → Account ID

### Authentication Issues
- Ensure: `az login` with correct account
- Verify role permissions (Contributor or higher)
- Check Databricks provider configuration

### State Lock Issues

If stuck:

```bash
# List locks
terraform force-unlock [LOCK_ID]

# Clean local state if needed
rm -rf .terraform/
terraform init
```

## Security Best Practices

1. **State File Security:**
   - Use remote backend (Azure Storage) with encryption
   - Enable versioning on state storage
   - Restrict access via RBAC

2. **Metastore Ownership:**
   - Use AAD groups instead of individual principals
   - Principle of least privilege for permissions

3. **Storage Security:**
   - UC storage account uses:
     - Private endpoints
     - Access restricted to managed identity
     - Network rules deny public access

4. **Credentials Management:**
   - Never commit `*.tfvars` with sensitive data
   - Use Azure Key Vault for secrets
   - Use `terraform.tfvars` (gitignored) for local values

5. **Audit & Compliance:**
   - Enable audit logging on storage account
   - Monitor UC operations via Databricks workspace audit logs
   - Review IAM assignments regularly

## Next Steps

1. **Configure additional catalogs** for different teams/projects
2. **Set up external locations** for data sources outside Databricks
3. **Implement data governance policies** via UC grants and permissions
4. **Set up data lineage** using Delta Live Tables
5. **Configure CI/CD pipelines** for automated Terraform deployments

## References

- [Databricks Unity Catalog Documentation](https://docs.databricks.com/en/data-governance/unity-catalog/index.html)
- [Databricks Terraform Provider](https://registry.terraform.io/providers/databricks/databricks/latest/docs)
- [Azure Terraform Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [GitHub Databricks Examples](https://github.com/databricks/terraform-databricks-examples)
