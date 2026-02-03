# Secure Azure Databricks with Azure ML and AI Foundry - Infrastructure as Code

This project provides a complete Infrastructure as Code (IaC) solution for deploying a secure, enterprise-grade data and AI platform on Azure. It combines Azure Databricks, Azure Machine Learning, AI Foundry, and optional AKS for a comprehensive data and AI solution with strong security, governance, and networking controls.

## 🏗️ Architecture Overview

### Components Deployed

```
┌─────────────────────────────────────────────────────┐
│                  Azure VNet (10.0.0.0/16)           │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────────┐  ┌──────────────────┐       │
│  │  Databricks      │  │   Azure ML       │       │
│  │  Workspace       │  │   Workspace      │       │
│  │  (VNet Inject)   │  │                  │       │
│  └──────────────────┘  └──────────────────┘       │
│                                                     │
│  ┌──────────────────┐  ┌──────────────────┐       │
│  │   AI Foundry     │  │   AKS Cluster    │       │
│  │   Hub            │  │   (Optional)     │       │
│  └──────────────────┘  └──────────────────┘       │
│                                                     │
│  ┌──────────────────────────────────────────┐     │
│  │      Private Endpoints (Secure)         │     │
│  │  • Storage Account (Blob, DFS, File)    │     │
│  │  • Key Vault                            │     │
│  │  • Container Registry                   │     │
│  │  • Azure ML                             │     │
│  │  • AI Foundry                           │     │
│  └──────────────────────────────────────────┘     │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Security Features

✅ **Network Isolation**
- Virtual Network with multiple subnets for different services
- Network Security Groups with restrictive ingress/egress rules
- Private endpoints for all data services (no internet exposure)
- Service endpoints for Azure services

✅ **Data Exfiltration Protection**
- Databricks Secure Cluster Connectivity (No Public IP)
- Network-level controls to prevent unauthorized data movement
- Disabled public network access on all services

✅ **Encryption & Compliance**
- Infrastructure encryption enabled on all storage services
- HTTPS-only connections (TLS 1.2 minimum)
- Private endpoint DNS zones for secure name resolution
- Geo-redundant storage for disaster recovery

✅ **Identity & Access Control**
- Azure Entra ID integration (no shared keys)
- RBAC for all Azure resources
- Managed identities for service-to-service authentication
- Key Vault with purge protection

✅ **Data Governance**
- Unity Catalog for centralized data governance
- Delta Sharing for secure cross-org data sharing
- Audit logging across all services

## 📋 Prerequisites

1. **Azure CLI** (version 2.50.0 or later)
   ```bash
   # Install from: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
   az --version
   ```

2. **Azure Developer CLI (azd)** (version 1.10.0 or later)
   ```bash
   # Install from: https://aka.ms/install-azd
   azd version
   ```

3. **Bicep CLI** (included with Azure CLI)
   ```bash
   az bicep version
   ```

4. **Azure Subscription** with appropriate permissions
   - Owner or Contributor role
   - Ability to create resource groups

5. **Get Your Object ID**
   ```bash
   az ad signed-in-user show --query id -o tsv
   ```
   Save this for the `adminObjectId` parameter.

## 🚀 Deployment Instructions

### Step 1: Clone or Setup the Project

```bash
cd d:\Databricks\dbx-demos\Azure-Databricks-AzureML
```

### Step 2: Initialize Azure Developer CLI

```bash
azd init --template secure-databricks-azureml
```

Or manually configure:

```bash
# Set environment name
azd env new dev

# Set Azure subscription
azd config set auth.useAzureCLIForAuth true
az login
```

### Step 3: Configure Parameters

Edit `infra/main.bicepparam`:

```bicep
param environmentName = 'dev'          # dev, staging, or prod
param location = 'eastus'              # Azure region
param projectName = 'secure-db'        # Project name prefix
param adminObjectId = ''               # Your object ID from Step 1
param deployAKS = false                # Set to true if you want AKS
param aksNodeCount = 3                 # Number of AKS nodes
```

### Step 4: Validate Bicep Files

```bash
az bicep build-params --file infra/main.bicepparam
```

### Step 5: Preview Deployment

```bash
azd provision --preview
```

Review the changes and ensure they match your expectations.

### Step 6: Deploy Infrastructure

```bash
azd provision
```

This will:
- Create resource group
- Deploy VNet with all subnets
- Deploy Databricks workspace with VNet injection
- Deploy Azure ML workspace
- Deploy AI Foundry hub
- Deploy optional AKS cluster
- Configure private endpoints for all services
- Create storage accounts and key vaults

**Deployment typically takes 15-30 minutes.**

## 📦 What Gets Deployed

### Resource Group
- `rg-secure-db-dev-{unique-suffix}`

### Networking
- Virtual Network (10.0.0.0/16)
- Subnets for Databricks, Azure ML, AKS, and private endpoints
- Network Security Groups with security rules
- Private DNS zones for all services

### Data Platform
- **Azure Databricks**
  - Premium SKU (required for Unity Catalog)
  - VNet injection enabled
  - Secure Cluster Connectivity (No Public IP)
  - Ready for Unity Catalog configuration
  - Delta Sharing support

- **Storage Account** (ADLS Gen2)
  - Hierarchical namespace enabled (for Unity Catalog)
  - 3x replication (RAGRS)
  - Blob versioning and soft delete
  - Private endpoints for Blob, DFS, File services

- **Azure Key Vault**
  - Premium SKU
  - Purge protection enabled
  - RBAC-based access
  - Private endpoint

- **Azure Container Registry**
  - Premium SKU
  - Soft delete and quarantine policies
  - Private endpoint
  - Zone-redundant storage

### AI/ML Services
- **Azure Machine Learning Workspace**
  - Basic SKU
  - Private endpoint
  - Application Insights integration
  - CPU compute cluster (auto-scaling)

- **Azure AI Foundry Hub**
  - Network-isolated
  - Integration with Azure ML resources
  - Shared storage and key vault

- **Azure Kubernetes Service** (Optional)
  - Linux nodes (Azure Linux OS)
  - System and user node pools
  - Auto-scaling enabled
  - Private cluster (no public IP)
  - Azure CNI with Cilium
  - Pod Security Standards
  - Microsoft Defender for Containers (optional)

## 🔧 Post-Deployment Configuration

### 1. Configure Unity Catalog (Databricks)

After deployment, set up Unity Catalog metastore:

```bash
# Get Databricks workspace URL
az databricks workspace show \
  --resource-group <resource-group-name> \
  --name <workspace-name> \
  --query workspaceUrl

# Install Databricks CLI
pip install databricks-cli

# Configure CLI
export DATABRICKS_HOST=<workspace-url>
export DATABRICKS_TOKEN=<your-pat-token>

# Create metastore
databricks unity-catalog metastores create \
  --name main \
  --storage-root "abfss://unity-catalog@<storage-account>.dfs.core.windows.net/"

# Assign to workspace
databricks unity-catalog metastores assign \
  --workspace-id <workspace-id> \
  --metastore-id <metastore-id>
```

### 2. Enable Delta Sharing (Databricks)

Configure Delta Sharing on the Unity Catalog metastore:

```bash
# Enable Delta Sharing
databricks unity-catalog delta-sharing enable \
  --metastore-id <metastore-id> \
  --default-share-credentials-provider <provider-name>

# Create a share
databricks unity-catalog shares create \
  --name products-share \
  --storage-path "/Shared/Products"
```

### 3. Connect Azure ML to Databricks

In Azure ML workspace, create a Databricks linked service:

```python
from azure.ai.ml import MLClient
from azure.identity import DefaultAzureCredential

ml_client = MLClient.from_config(credential=DefaultAzureCredential())

# Link Databricks workspace
databricks_compute = DatabricksCompute(
    name="databricks-link",
    databricks_workspace_url="<workspace-url>",
)
```

### 4. Configure AKS for Model Serving (if deployed)

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group <resource-group-name> \
  --name <aks-cluster-name> \
  --admin

# Deploy Azure ML inference endpoint
az ml online-deployment create \
  --resource-group <resource-group-name> \
  --workspace-name <workspace-name> \
  --endpoint-name <endpoint-name> \
  --deployment-config-path deployment.yml
```

## 🔐 Security Best Practices Implemented

### 1. Network Security
- ✅ VNet injection for Databricks (no public internet exposure)
- ✅ Private endpoints for all Azure services
- ✅ Network Security Groups with allow-list rules
- ✅ No public IP addresses for compute resources
- ✅ Private DNS zones for secure name resolution

### 2. Data Security
- ✅ All storage encrypted at-rest (infrastructure encryption)
- ✅ TLS 1.2 minimum for all connections
- ✅ Blob versioning and soft delete enabled
- ✅ No anonymous access to storage
- ✅ Shared key access disabled (Entra ID only)

### 3. Access Control
- ✅ RBAC for all Azure resources
- ✅ Managed identities for service-to-service auth
- ✅ No hardcoded credentials
- ✅ Key Vault for secrets management
- ✅ Private endpoint for Key Vault

### 4. Compliance & Governance
- ✅ Azure Databricks Unity Catalog
- ✅ Delta Sharing for secure data sharing
- ✅ Audit logging on all services
- ✅ Azure Policy integration (AKS)
- ✅ Defender for Containers (AKS)

## 📊 Databricks Security Features

### Data Exfiltration Protection
The Databricks workspace is configured with:
- **Secure Cluster Connectivity (NPIP)**: No public IP addresses on clusters
- **Network Rules**: Strict NSG rules allow only required traffic
- **Storage Access**: Private endpoints restrict access to authorized networks
- **Service Endpoints**: Secure paths to Azure services

### Unity Catalog Setup
```
┌─────────────────────┐
│   Metastore        │
│  (Storage Root)    │
└──────────┬──────────┘
           │
┌──────────▼──────────────────┐
│   Catalogs (External)      │
│  • prod_catalog            │
│  • analytics_catalog       │
└──────────┬──────────────────┘
           │
┌──────────▼──────────────────┐
│   Schemas                  │
│  • raw_data                │
│  • processed_data          │
└──────────┬──────────────────┘
           │
┌──────────▼──────────────────┐
│   Tables & Volumes         │
│  • customer_data           │
│  • transaction_history     │
└────────────────────────────┘
```

### Delta Sharing Setup
```
Provider Workspace (Unity Catalog)
├── Create Share (read-only collection)
├── Add Tables/Volumes/Models
├── Create Recipients
│   ├── Databricks-to-Databricks (other accounts)
│   └── Open Sharing (any platform)
└── Grant Access & Monitor
```

## 📝 Configuration Files

### `azure.yaml`
- azd project configuration
- Bicep provider settings
- Deployment hooks

### `infra/main.bicep`
- Main orchestration template
- Resource group creation
- Module composition

### `infra/modules/`
- `networking.bicep`: VNets, subnets, NSGs
- `databricks.bicep`: Databricks workspace
- `storage.bicep`: ADLS Gen2 with private endpoints
- `keyvault.bicep`: Key Vault with RBAC
- `acr.bicep`: Container Registry
- `azureml.bicep`: Azure ML workspace
- `ai-foundry.bicep`: AI Foundry hub
- `aks.bicep`: AKS cluster (optional)

### `infra/main.bicepparam`
- Parameter values for deployment
- Environment-specific settings

## 🧪 Testing & Validation

### Validate Bicep Syntax

```bash
az bicep validate --file infra/main.bicep
az bicep build-params --file infra/main.bicepparam
```

### Test Network Connectivity

```bash
# From Databricks cluster
dbutils.fs.ls("abfss://unity-catalog@<storage>.dfs.core.windows.net/")

# Should succeed without internet access through private endpoints
```

### Verify Private Endpoints

```bash
az network private-endpoint list \
  --resource-group <resource-group-name> \
  --output table
```

### Check NSG Rules

```bash
az network nsg rule list \
  --resource-group <resource-group-name> \
  --nsg-name <nsg-name> \
  --output table
```

## 📈 Scaling & Optimization

### Databricks Cluster Scaling
- Configure auto-scaling in cluster policies
- Use spot instances for cost optimization
- Implement cluster auto-termination

### Azure ML Compute Scaling
- Auto-scaling enabled (min: 0, max: 10 nodes)
- Configure per workload needs
- Use GPU VMs for ML workloads (D4s_v3 → GPU VMs)

### AKS Node Scaling
- System pool: auto-scaling (1-10 nodes)
- User pool: auto-scaling (0-20 nodes)
- Taints for inference workloads

### Storage Performance
- Premium tier for hot data
- Archive tier for long-term retention
- Enable CDN for blob content distribution

## 💰 Cost Optimization

1. **Right-size VMs**
   - Use spot instances for non-critical workloads
   - Scale down during off-hours

2. **Storage Tiers**
   - Use Hot tier for active data
   - Move to Cool/Archive after 30/90 days
   - Enable lifecycle policies

3. **Compute Optimization**
   - Enable auto-scaling on all compute pools
   - Use Reserved Instances for predictable workloads
   - Implement cluster auto-termination

4. **Monitor Costs**
   ```bash
   az cost management export list \
     --scope "/subscriptions/<subscription-id>" \
     --output table
   ```

## 🔍 Monitoring & Logging

### Application Insights
- Azure ML metrics and traces
- Custom application monitoring
- Performance analytics

### Diagnostic Logs
Enable diagnostics for:
- Virtual Network (NSG flow logs)
- Storage Account (blob access logs)
- Key Vault (access logs)
- AKS (audit logs)

### Azure Monitor Queries

```kusto
// Track Databricks API calls
AzureDiagnostics
| where ResourceProvider == "Microsoft.Databricks"
| summarize Count=count() by OperationName

// Monitor storage access
StorageBlobLogs
| where TimeGenerated > ago(24h)
| summarize AccessCount=count() by Identity
```

## 🗑️ Cleanup

To remove all deployed resources:

```bash
# Via azd
azd down --force

# Via Azure CLI
az group delete \
  --name <resource-group-name> \
  --yes --no-wait
```

**⚠️ WARNING**: This will permanently delete all resources including data. Ensure you have backups.

## 🤝 Contributing & Support

### Common Issues

**Issue**: Private endpoint DNS resolution fails
```bash
# Solution: Verify DNS zone links
az network private-dns zone list --resource-group <rg>
az network private-dns zone virtual-network-link list \
  --zone-name <zone-name> \
  --resource-group <rg>
```

**Issue**: Databricks workspace not connecting
```bash
# Solution: Check NSG rules
az network nsg rule list --nsg-name <nsg> --resource-group <rg>
```

**Issue**: Azure ML workspace creation timeout
```bash
# Solution: Check ARM template deployment
az deployment group list --resource-group <rg> --output table
```

## 📚 Additional Resources

- [Azure Databricks Documentation](https://learn.microsoft.com/en-us/azure/databricks/)
- [Azure Databricks Data Exfiltration Protection](https://www.databricks.com/blog/data-exfiltration-protection-with-azure-databricks)
- [Delta Sharing Guide](https://learn.microsoft.com/en-us/azure/databricks/delta-sharing/)
- [Azure ML Network Security](https://learn.microsoft.com/en-us/azure/machine-learning/concept-network-security)
- [AKS Network Policies](https://learn.microsoft.com/en-us/azure/aks/use-network-policies)
- [Azure Security Best Practices](https://learn.microsoft.com/en-us/azure/security/fundamentals/best-practices-and-patterns)

## 📄 License

This Infrastructure as Code is provided as-is under the MIT License.

---

**Last Updated**: February 2, 2026
**Version**: 1.0.0
**Maintained By**: Your Organization
