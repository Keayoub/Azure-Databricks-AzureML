# Unity Catalog Configuration with Bicep

This guide explains how the Unity Catalog is configured in the Bicep-based deployment using deployment scripts.

## Overview

Instead of using Terraform after Bicep deployment, we've implemented **Unity Catalog configuration directly in Bicep** using Azure Deployment Scripts. This keeps everything in one IaC language and provides a complete, automated setup.

## Architecture

```
Bicep Deployment
    ↓
Databricks Workspace (Premium SKU)
    ↓
Unity Catalog Module (deployment script)
    ├── Uses managed identity for authentication
    ├── Calls Databricks REST API
    └── Configures:
        ├── Metastore (storage root)
        ├── External locations
        ├── Catalogs (raw_data, processed_data, analytics)
        ├── Schemas (bronze, silver, gold, reports, ml_features)
        └── Delta Sharing (enabled)
```

## Components

### 1. Unity Catalog Bicep Module
**File**: `infra/modules/unity-catalog.bicep`

Creates a deployment script resource that:
- Uses managed identity for secure authentication
- Calls the Databricks REST API v2.0
- Configures metastore, external locations, catalogs, and schemas
- Enables Delta Sharing

### 2. Configuration PowerShell Script
**File**: `infra/modules/scripts/setup-unity-catalog.ps1`

Performs these operations:
1. **Get Databricks Token**: Uses managed identity to authenticate with Databricks API
2. **Create Metastore**: Sets up Unity Catalog metastore with ADLS Gen2 storage root
3. **Assign Metastore**: Connects metastore to workspace
4. **Create Storage Credential**: Configures storage access
5. **Create External Location**: Sets up ADLS Gen2 external location
6. **Create Catalogs**: Creates three default catalogs:
   - `raw_data` - Bronze layer (raw incoming data)
   - `processed_data` - Silver/Gold layers (cleaned and business data)
   - `analytics` - Reports and ML features
7. **Create Schemas**: Creates organized schemas within each catalog:
   - `raw_data.bronze` - Raw ingestion layer
   - `processed_data.silver` - Cleaned and standardized data
   - `processed_data.gold` - Business-ready data
   - `analytics.reports` - Analytics and dashboards
   - `analytics.ml_features` - Machine learning features
8. **Enable Delta Sharing**: Activates Delta Sharing on the metastore

## Deployment Flow

### Step 1: Deploy Bicep Template
```bash
azd provision
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
```
Metastore
├── raw_data (External Catalog)
│   └── bronze (Schema - raw data from sources)
├── processed_data (External Catalog)
│   ├── silver (Schema - cleaned and deduplicated)
│   └── gold (Schema - aggregated business data)
└── analytics (External Catalog)
    ├── reports (Schema - aggregated analytics)
    └── ml_features (Schema - ML feature engineering)
```

### Delta Sharing Configuration
- **Status**: Enabled on metastore
- **Scope**: ALL (supports both open and Databricks-to-Databricks sharing)
- **Use cases**:
  - Share analytics with external partners
  - Share data between Databricks accounts
  - Create data marketplace products

## Required Parameters

Update `infra/main.bicepparam` with:

```bicep
// Enable Unity Catalog configuration
param enableUnityCatalog = true

// Databricks workspace parameters
param enableDeltaSharing = true  // Enables Delta Sharing on metastore

// Storage and admin
param adminObjectId = '<your-object-id>'  // For RBAC assignments
```

## Managed Identity Configuration

The deployment script uses a **User-Assigned Managed Identity** for authentication:

1. **Identity Creation**: Bicep creates `uai-unity-catalog-{project}-{environment}`
2. **Token Acquisition**: Script uses managed identity to get Databricks API token
3. **Permissions**: Identity needs:
   - Contributor role on Databricks workspace
   - Storage Blob Data Contributor on storage account

```bash
# Verify managed identity was created
az identity list -g <resource-group> -o table

# Check role assignments
az role assignment list -g <resource-group> --output table
```

## Post-Deployment Verification

### 1. Verify Metastore Creation
In Databricks workspace:

```sql
-- List metastores
SELECT * FROM system.information_schema.metastores;

-- List catalogs
SELECT * FROM system.information_schema.catalogs;

-- List schemas
SELECT * FROM system.information_schema.schemata;
```

### 2. Create Sample Table
```sql
CREATE TABLE IF NOT EXISTS raw_data.bronze.sample_events (
  event_id STRING,
  event_timestamp TIMESTAMP,
  event_type STRING,
  user_id STRING
)
USING DELTA
COMMENT "Sample events table";

-- Verify table
SELECT * FROM raw_data.bronze.sample_events;
```

### 3. Test Delta Sharing
```python
# List available shares
shares = spark.sql("SHOW SHARES").collect()
print(f"Available shares: {len(shares)}")

# Enable notebook sharing
spark.sql("CREATE SHARE analytics_share")
spark.sql("ALTER SHARE analytics_share ADD TABLE analytics.reports.*")
```

### 4. Check Deployment Script Logs
```bash
# View deployment script execution logs
az deployment group show \
  --resource-group <resource-group> \
  --name <deployment-name> \
  --query "properties.outputs" -o json

# View PowerShell script output
az resource list -g <resource-group> --resource-type Microsoft.Resources/deploymentScripts -o table
```

## Customization

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
