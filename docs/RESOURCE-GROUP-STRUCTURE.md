# Azure Databricks + AI Platform Deployment Structure

## Resource Group Organization

Your infrastructure is now organized into **3 separate resource groups** for better management and security:

### 1. **Shared Services Resource Group** (`rg-{projectName}-shared-{environment}`)
Contains shared infrastructure used by all components:
- **Virtual Network (VNet)** with multiple subnets
  - Databricks private/public subnets
  - Azure ML compute subnet
  - Private endpoints subnet
  - AKS subnet (optional)
- **Storage Accounts**
  - ADLS Gen2 for Unity Catalog
  - ML workspace storage
- **Key Vault**
  - Credentials and secrets management
- **Container Registry (ACR)**
  - Docker image storage
- **Access Connector** (Unity Catalog)
  - Managed identity for storage access
- **AKS Cluster** (optional)
  - For Azure ML model serving

### 2. **Databricks Infrastructure Resource Group** (`rg-{projectName}-databricks-{environment}`)
Contains Databricks-specific resources:
- **Azure Databricks Workspace**
  - Premium SKU for Unity Catalog support
  - VNet injection for network isolation
  - Secure cluster connectivity (no public IP)
  - Data exfiltration protection

### 3. **AI Platform Resource Group** (`rg-{projectName}-ai-platform-{environment}`)
Contains Azure ML and AI Foundry resources:
- **Azure ML Workspace**
  - With private endpoints
  - Private DNS zone
  - System-assigned managed identity
- **AI Foundry Hub**
  - For model management and serving
  - Network-isolated deployment

## Benefits of This Structure

| Aspect | Benefit |
|--------|---------|
| **Separation of Concerns** | Each RG serves a specific purpose |
| **Access Control** | Granular RBAC per resource group |
| **Cost Tracking** | Easy to track costs by component |
| **Lifecycle Management** | Can manage RGs independently |
| **Team Organization** | Different teams can manage different RGs |
| **Security Boundaries** | Stronger isolation between components |

## Deployment Instructions

### 1. Update Parameters
Edit `infra/main.bicepparam`:
```bicep
param environmentName = 'dev'
param projectName = 'dbxaml'
param adminObjectId = '<your-object-id>'  # Get from: az ad signed-in-user show --query id -o tsv
```

### 2. Deploy All Resource Groups
```powershell
azd provision
```

This will automatically create all 3 resource groups and deploy resources to each:
- Shared services to `rg-{projectName}-shared-{environment}`
- Databricks to `rg-{projectName}-databricks-{environment}`
- AI Platform to `rg-{projectName}-ai-platform-{environment}`

### 3. Configure After Deployment
```powershell
# Configure Unity Catalog
pwsh ./scripts/configure-unity-catalog.ps1
```

## Resource Group Cross-References

Resources in different RGs communicate through:
- **Resource IDs**: Full ARM resource paths
- **Output References**: Outputs from Shared RG modules are passed to other RGs
- **Network Connectivity**: All RGs share the same VNet (in Shared RG)

### Example: How Databricks Accesses Storage
```
Databricks RG
    └── Azure Databricks Workspace
         └── References VNet from Shared RG
         └── Access credentials from Key Vault (Shared RG)
         └── Access storage account (Shared RG) via private endpoint
```

## Cleaning Up

To delete all resource groups:
```powershell
azd down --purge
```

Or delete individually:
```powershell
# Delete each resource group
az group delete --name rg-dbxaml-shared-dev
az group delete --name rg-dbxaml-databricks-dev
az group delete --name rg-dbxaml-ai-platform-dev
```

## Key Outputs

After deployment, check these outputs:
```powershell
# List all outputs
azd show

# Or query specific outputs
az deployment sub show --name <deployment-id> --query properties.outputs
```

Key outputs include:
- Resource group names and IDs
- Databricks workspace URL
- Azure ML workspace ID
- AI Foundry hub ID
- Networking configuration
- Storage account details

---

**Modified**: February 4, 2026  
**Structure**: 3-Tier Resource Group Organization
