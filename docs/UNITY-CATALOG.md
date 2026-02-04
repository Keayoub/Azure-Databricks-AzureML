# Unity Catalog Configuration with Bicep

This guide explains how the Unity Catalog is configured in the Bicep-based deployment using deployment scripts.

## Overview

The deployment automatically configures Unity Catalog with a **medallion architecture** organized by **line of business (LoB) teams** across different **environments** (dev, QA, prod).

## Data Structure

```
Metastore (1 per region - Canada East)
    ├── dev_lob_team_1
    │     ├── bronze (raw incoming data)
    │     ├── silver (cleaned and validated data)
    │     └── gold (business-ready data)
    ├── dev_lob_team_2
    │     ├── bronze
    │     ├── silver
    │     └── gold
    ├── dev_lob_team_3
    │     ├── bronze
    │     ├── silver
    │     └── gold
    ├── qa_lob_team_1 (when environment = qa)
    ├── qa_lob_team_2
    ├── qa_lob_team_3
    ├── prod_lob_team_1 (when environment = prod)
    ├── prod_lob_team_2
    └── prod_lob_team_3
```

## Components

### 1. Unity Catalog Bicep Module

The deployment automatically configures Unity Catalog with a **medallion architecture** organized by **line of business (LoB) teams** across different **environments** (dev, QA, prod).

### 2. Configuration PowerShell Script

1. **Get Databricks Token**: Uses managed identity to authenticate with Databricks API

### 3. Schema Organization

- **gold**: Business-ready data layer (aggregated and optimized for analytics)

7. **Create Schemas**: Creates organized schemas within each catalog:

8. **Enable Delta Sharing**: Activates Delta Sharing on the metastore

## Deployment Flow

### Step 1: Deploy Bicep Template

```
```bash
```

This deploys:
1. ✅ Networking infrastructure (VNet, subnets, NSGs)
2. ✅ Storage account (ADLS Gen2)
3. ✅ Databricks workspace (Premium SKU, VNet-injected)
4. ✅ Azure ML workspace
5. ✅ AI Foundry hub
6. ✅ (Optional) AKS cluster

### Step 2: Unity Catalog Configuration (Automatic)
Once Databricks workspace is ready, the deployment script automatically:
1. Retrieves workspace URL and ID from Bicep outputs
2. Uses managed identity to get Databricks API token
3. Creates and configures Unity Catalog metastore
4. Sets up catalogs, schemas, and external locations
5. Enables Delta Sharing

**Deployment time**: ~5-10 minutes additional

## Configuration Details

### Storage Structure
```
Storage Account: st{project}{env}{hash}
├── Container: unity-catalog (metastore root)
│   ├── _delta_log/
│   ├── .metadata/
│   └── [catalog-data]/
├── Container: azureml
│   └── [ml-artifacts]/
└── Container: data
    └── [raw-data]/
```

### Catalog Hierarchy

- **gold**: Business-ready data layer (aggregated and optimized for analytics)

### Delta Sharing Configuration

```bicep
// Enable Unity Catalog configuration
```

### Verify Table

### Check Deployment Script Logs

### Modify Catalog Names

Edit `infra/modules/unity-catalog.bicep`:

```bicep
var catalogNames = [
  'your_catalog_1'
  'your_catalog_2'
  'your_catalog_3'
]
```

Then update the PowerShell script `setup-unity-catalog.ps1`:

```powershell
$catalogNames = @("your_catalog_1", "your_catalog_2", "your_catalog_3")
```

### Add Custom Schemas
Modify `setup-unity-catalog.ps1`:

```powershell
$schemas = @(
    @{ catalog = "your_catalog"; schema = "your_schema"; comment = "Your description" }
    # Add more schemas...
)
```

### Modify Storage Credentials
For different authentication methods:

```powershell
# Service Principal (in setup-unity-catalog.ps1)
'azure_service_principal' = @{
    'directory_id'    = $tenantId
    'application_id'  = $servicePrincipalId
    'client_secret'   = $servicePrincipalSecret
}

# Or use managed identity (current default)
# No changes needed - uses workspace managed identity
```

## Troubleshooting

### Issue: Deployment Script Fails to Get Token
**Solution**: Verify managed identity has correct permissions
```bash
az role assignment create \
  --assignee <managed-identity-id> \
  --role Contributor \
  --scope <workspace-resource-id>
```

### Issue: "Cannot access storage account"
**Solution**: Ensure managed identity has Storage Blob Data Contributor role
```bash
az role assignment create \
  --assignee <managed-identity-id> \
  --role "Storage Blob Data Contributor" \
  --scope <storage-account-resource-id>
```

### Issue: Unity Catalog metastore already exists
**Solution**: Script automatically detects and reuses existing metastore
- Check deployment script output for metastore ID
- Script is idempotent - can be re-run safely

### Issue: Schemas or catalogs not created
**Solution**: Check PowerShell script output
```bash
# Get deployment script outputs
az resource show \
  --resource-group <rg> \
  --name <deployment-script-name> \
  --resource-type "Microsoft.Resources/deploymentScripts" \
  --query "properties.outputs" -o json
```

## Security Considerations

### 1. Managed Identity Authentication
- ✅ No credentials in scripts
- ✅ No personal access tokens needed
- ✅ Token scoped to specific resource
- ✅ Automatically rotated by Azure

### 2. Storage Access
- ✅ Private endpoint for storage account
- ✅ Only managed identity can access
- ✅ Network isolation with NSGs
- ✅ Infrastructure encryption enabled

### 3. Databricks API Access
- ✅ HTTPS only
- ✅ Bearer token authentication
- ✅ Minimal permissions (only Unity Catalog APIs)
- ✅ Audit logging available

## Cost Optimization

### Deployment Script Costs
- Minimal: Azure Container Instances run only during deployment
- No persistent costs after deployment completes
- Logs retained for 1 hour (configurable)

### Unity Catalog Storage Costs
- Charged at standard ADLS Gen2 rates
- No additional Unity Catalog licensing
- Data hot storage: ~$0.02-0.04 per GB/month
- Archive storage: ~$0.001 per GB/month

## Next Steps

1. **Deploy**: Run `azd provision` to deploy infrastructure and Unity Catalog
2. **Verify**: Run SQL queries to verify catalogs and schemas
3. **Load Data**: Ingest data into `raw_data.bronze.*` tables
4. **Transform**: Create views and tables in `processed_data.silver.*` and `.gold.*`
5. **Share**: Enable Delta Sharing for external access
6. **Monitor**: Track usage via Databricks audit logs

## References

- [Azure Databricks Unity Catalog](https://learn.microsoft.com/en-us/azure/databricks/data-governance/unity-catalog/)
- [Delta Sharing](https://learn.microsoft.com/en-us/azure/databricks/delta-sharing/)
- [Databricks REST API - Unity Catalog](https://docs.databricks.com/api/workspace/catalogs)
- [Azure Deployment Scripts](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deployment-script-template)

---

**Created**: February 2, 2026
**Bicep Version**: 1.0.0
**Status**: Production Ready
