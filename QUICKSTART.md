# 🚀 Quick Start Guide

**Estimated time: 20 minutes** (5 min setup + 15 min deployment)

---

## Step 1: Install Prerequisites (1 minute)

**Cross-platform** - Works on Windows, macOS, and Linux!

Requirements: **PowerShell 7.0+** ([download](https://learn.microsoft.com/powershell/scripting/install/installing-powershell))

```powershell
# Install all tools at once
pwsh ./scripts/install-prerequisites.ps1

# Or upgrade existing tools
pwsh ./scripts/install-prerequisites.ps1 -Upgrade
```

This installs automatically:
- Python 3.7+
- Azure CLI
- Azure Developer CLI  
- Databricks CLI
- Required dependencies

## Step 2: Prepare Deployment (2 minutes)

```bash
# 1. Get your Azure object ID
az login
az ad signed-in-user show --query id -o tsv

# 2. Edit infra/main.bicepparam
# Set: param adminObjectId = '<your-object-id-from-above>'
#      param environmentName = 'dev'
#      param location = 'canadaeast'
```

## Step 3: Deploy Infrastructure (15 minutes)

```bash
# Initialize (first time only)
azd env new dev

# Deploy
azd provision

# Or with preview first
azd provision --preview
```

✅ **Deployment complete!** Your secure Databricks workspace is ready.

---

## ✅ What You Get

- **Azure Databricks** (Premium, VNet injection, no public IP)
- **Azure Storage** (ADLS Gen2 with HNS for Unity Catalog)
- **Private Endpoints** (all services private)
- **Security** (VNet isolation, NSGs, managed identities)
- **Ready for**: Unity Catalog, Azure ML, AI Foundry

---

## 🎯 Next Steps

### 1. Access Your Workspace

```bash
# Get workspace URL
az databricks workspace show \
  --name "dbw-secure-db-dev" \
  --resource-group "rg-secure-db-dev-*" \
  --query "properties.workspaceUrl" -o tsv

# If you get "privacy settings disallow access" error:
# Run: ./link-databricks-dns.ps1
```

### 2. Set Up Unity Catalog (Manual)

```bash
# Configure Databricks CLI
databricks configure --token
# (Get token from workspace > Admin > User Settings > Access Tokens)

# Create metastore
databricks unity-catalog metastores create \
  --name metastore-dev \
  --storage-root "abfss://unity-catalog@<storage-account>.dfs.core.windows.net/" \
  --region canadaeast

# Get IDs for next steps
databricks unity-catalog metastores list --output json

# Assign metastore to workspace  
databricks unity-catalog metastores assign \
  --workspace-id <workspace-id> \
  --metastore-id <metastore-id>

# Create catalogs (bronze, silver, gold)
for catalog in bronze_dev silver_dev gold_dev; do
  databricks unity-catalog catalogs create \
    --name "$catalog" \
    --comment "Medallion architecture"
done
```

### 3. Deploy Azure ML (Optional)

Edit `infra/main.bicepparam`:
```bicep
param deployAzureML = true
param deployAIFoundry = true
```

Then run: `azd provision`

---

## 📚 Full Documentation

- **[README.md](./README.md)** - Complete project guide
- **[DEPLOYMENT-COMPLETE.md](./DEPLOYMENT-COMPLETE.md)** - What was deployed
- **[docs/POST-DEPLOYMENT.md](./docs/POST-DEPLOYMENT.md)** - Configuration checklist
- **[docs/PROJECT-STRUCTURE.md](./docs/PROJECT-STRUCTURE.md)** - Project layout

---

## 🆘 Troubleshooting

### Prerequisites Installation Failed

```bash
# Check Python version
python3 --version

# Check Azure CLI
az --version

# Manually install if needed
pip install databricks-cli azure-cli-core
```

### Can't Access Databricks from VM

1. Verify VNet peering is active
2. Run DNS linking script: `./link-databricks-dns.ps1`
3. Check private DNS zones are linked to your VNet

### Storage Access Denied

This is expected! The tenant policy prevents shared-key access (more secure).
- Use managed identities (Access Connector) instead
- Scripts ready in `infra/modules/scripts/`

### Deployment Failed

```bash
# Check what went wrong
azd provision --debug

# View deployment details
az deployment group list \
  --resource-group "rg-secure-db-dev-*" \
  --query "[0].properties.statusMessage"
```

---

## 📊 Key Resources After Deployment

| Resource | Name | Where to Find |
|----------|------|---------------|
| Databricks Workspace | `dbw-secure-db-dev-*` | Azure Portal → Databricks |
| Storage Account (UC) | `stsecuredbdev*` | Azure Portal → Storage Accounts |
| Container Registry | `acrsecuredbdev*` | Azure Portal → Container Registries |
| Key Vault | `kv-secure-db-dev-*` | Azure Portal → Key Vaults |
| Resource Group | `rg-secure-db-dev-*` | Azure Portal → Resource Groups |

---

## 💡 Quick Tips

- **Workspace URL format**: `https://<workspace-id>.cloud.databricks.com`
- **Find workspace ID**: Azure Portal → Databricks resource → URL contains it
- **Databricks token**: Workspace → Admin → User Settings → Access Tokens → Generate
- **Storage account key**: Not needed! Uses managed identity instead (more secure)

---

## 🎓 Architecture Overview

```
┌─────────────────────────────────────────┐
│       Azure Virtual Network             │
│       (10.0.0.0/16)                     │
│                                         │
│  ┌──────────────┐  ┌──────────────┐   │
│  │ Databricks   │  │   Storage    │   │
│  │ (No Pub IP)  │  │  (Private)   │   │
│  └──────────────┘  └──────────────┘   │
│                                         │
│  ┌──────────────┐  ┌──────────────┐   │
│  │  Key Vault   │  │   ACR        │   │
│  │  (Private)   │  │  (Private)   │   │
│  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────┘
         ↓
   Private Endpoints
         ↓
   Private DNS Zones
         ↓
   Network Security Groups (NSGs)
```

---

**Status**: ✅ Ready to Deploy  
**Next Action**: Run prerequisites install script, then deploy!
