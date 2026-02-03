# Deployment Guide

## Quick Start

### Prerequisites
- Azure CLI (v2.50+)
- Azure Developer CLI (v1.10+)
- Azure subscription with Owner/Contributor role

### Get Your Object ID
```bash
az ad signed-in-user show --query id -o tsv
```

### Step 1: Configure Parameters

Edit `infra/main.bicepparam`:
```bicep
param environmentName = 'dev'          # dev, qa, or prod
param location = 'canadaeast'          # Azure region
param projectName = 'secure-db'        # Project name prefix
param adminObjectId = '<your-object-id>'
param enableUnityCatalog = true
```

### Step 2: Validate & Deploy

```bash
# Validate Bicep
az bicep build-params --file infra/main.bicepparam

# Preview deployment
azd provision --preview

# Deploy
azd provision
```

**Deployment time: 15-30 minutes**

## What Gets Deployed

### Infrastructure
- Virtual Network with private subnets
- Network Security Groups and Private DNS zones
- Storage Account (ADLS Gen2)
- Key Vault (Premium SKU)
- Container Registry (Premium SKU)

### Services
- **Azure Databricks** (Premium SKU, VNet injection)
- **Azure Machine Learning** workspace
- **Azure AI Foundry** hub
- **Azure Kubernetes Service** (optional)

### Data Governance
- **Unity Catalog** metastore
- **3 LoB catalogs** per environment with Bronze/Silver/Gold schemas
- **Delta Sharing** enabled

## Post-Deployment

### Verify Deployment
```bash
# Get resource group
az group list --query "[?contains(name, 'secure-db')]"

# Get Databricks workspace URL
az databricks workspace show \
  --resource-group <rg-name> \
  --name <workspace-name> \
  --query workspaceUrl
```

### Connect to Databricks
1. Open the workspace URL in a browser
2. Create a Personal Access Token (PAT)
3. Configure Databricks CLI or notebooks

### Next Steps
- [Configure Unity Catalog](./UNITY-CATALOG.md)
- [Post-Deployment Setup](./POST-DEPLOYMENT.md)
- [Security Best Practices](./docs/README.md)
