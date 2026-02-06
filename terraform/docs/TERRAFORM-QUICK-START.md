# Terraform + azd Quick Reference

## One-Command Deployment

```bash
export DATABRICKS_ACCOUNT_ID="your-account-id"
azd provision
```

✓ Bicep deploys infrastructure (3-5 min)
✓ Terraform deploys UC layer (2-3 min)
✓ Full Databricks Lakehouse ready

## What Gets Created

### Phase 1: Bicep (Azure Infrastructure)
- 4 Resource Groups (Shared, Databricks, AI Platform, Compute)
- Virtual Networks & Subnets (VNet-injected Databricks)
- Premium Databricks Workspace
- ADLS Gen2, Key Vault, Log Analytics
- Network Security Groups & RBAC assignments

### Phase 2: Terraform (Unity Catalog)
- UC Metastore with ADLS backend
- Access Connector (managed identity)
- 3 Layer Catalogs: bronze, silver, gold
- Schemas for data organization
- External locations & volumes
- Storage credentials & RBAC grants

## Environment Setup

```bash
# Required
export DATABRICKS_ACCOUNT_ID="your-databricks-account-id"

# Optional (defaults provided)
export ENVIRONMENT_NAME="dev"
export PROJECT_NAME="databricks"
```

Get your Databricks Account ID:
1. Go to https://accounts.azuredatabricks.net
2. In URL: `?o=YOUR_ACCOUNT_ID`
3. Or check Terraform backend config

## After Deployment

```bash
# Check resources created
az resource list --resource-group "your-rg" --query "[].{name:name, type:type}" -o table

# Get workspace URL
az databricks workspace show --name "dbw-*" --resource-group "your-rg" \
  --query "workspaceUrl" -o tsv

# Access Databricks
https://your-workspace.region.azuredatabricks.net
```

## Terraform State

By default, stored locally in `terraform/terraform.tfstate`

For team environments, configure Azure backend:
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "your-rg"
    storage_account_name = "your-tfstate-storage"
    container_name       = "tfstate"
    key                  = "uc.tfstate"
  }
}
```

## Common Operations

### Add Catalog
Edit `terraform/environments/main.tf`:
```hcl
catalogs = {
  new_catalog = { comment = "My catalog" }
}
```
Run: `terraform apply`

### List UC Resources
```bash
# Via Databricks CLI
databricks unity-catalogs list-catalogs --workspace-id WORKSPACE_ID

# Via REST
curl -H "Authorization: Bearer $DATABRICKS_TOKEN" \
  https://workspace.azuredatabricks.net/api/2.1/unity-catalog/catalogs
```

### Destroy All
```bash
cd terraform && terraform destroy
azd down  # Remove Bicep resources
```

## Troubleshooting

| Error | Solution |
|-------|----------|
| `DATABRICKS_ACCOUNT_ID not set` | `export DATABRICKS_ACCOUNT_ID="..."` |
| `Workspace not found` | Wait for Bicep deployment to complete |
| `Invalid account ID` | Use account ID from https://accounts.azuredatabricks.net |
| `Access denied to storage` | Check managed identity RBAC on storage account |

## Files Modified/Created

```
infra/
  scripts/
    postdeploy.sh             ← Terraform deployment hook
  
azure.yaml                    ← Updated with Terraform deployment step

terraform/
  modules/
    adb-uc-metastore/
      versions.tf             ← Provider versions
      README.md               ← Module documentation
      
  environments/
    main.tf                   ← Module composition
    variables.tf              ← Input variables
    
  README.md                   ← Deployment guide

docs/
  TERRAFORM-AZD-INTEGRATION.md ← Detailed integration guide
```

## Next Steps

1. **Verify deployment**: Check Databricks workspace is accessible
2. **Configure storage credentials**: Link external locations to storage accounts
3. **Assign permissions**: Grant catalog access to teams/groups
4. **Enable governance**: Set up Unity Catalog policies
5. **Ingest data**: Load data into bronze catalog
6. **Create pipelines**: Set up ETL from bronze → silver → gold

## Documentation

- [Terraform + azd Integration](../docs/TERRAFORM-AZD-INTEGRATION.md) - Full guide
- [Terraform UC Deployment](./README.md) - Terraform details
- [Bicep Architecture](../infra/README.md) - Infrastructure details
