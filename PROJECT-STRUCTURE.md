# Project Structure

```
secure-databricks-azureml/
│
├── README.md                           # Main project documentation
├── POST-DEPLOYMENT.md                  # Post-deployment configuration guide
├── ARCHITECTURE.md                     # Detailed architecture documentation
│
├── azure.yaml                          # Azure Developer CLI configuration
│
├── infra/                              # Infrastructure as Code (Bicep)
│   ├── main.bicep                      # Main orchestration template
│   ├── main.bicepparam                 # Parameter values (environment-specific)
│   │
│   └── modules/                        # Reusable Bicep modules
│       ├── networking.bicep            # VNets, subnets, NSGs, private endpoints
│       ├── databricks.bicep            # Azure Databricks workspace
│       ├── storage.bicep               # Azure Storage Account (ADLS Gen2)
│       ├── keyvault.bicep              # Azure Key Vault
│       ├── acr.bicep                   # Azure Container Registry
│       ├── azureml.bicep               # Azure Machine Learning workspace
│       ├── ai-foundry.bicep            # Azure AI Foundry hub
│       └── aks.bicep                   # Azure Kubernetes Service (optional)
│
├── .azdo/                              # Azure DevOps CI/CD
│   └── pipelines/
│       └── azure-dev.yml               # Deployment pipeline
│
├── scripts/                            # Helper scripts
│   ├── deploy.sh                       # Bash deployment script
│   └── deploy.bat                      # PowerShell deployment script
│
├── docs/                               # Additional documentation
│   ├── SECURITY.md                     # Security implementation details
│   ├── UNITY-CATALOG.md                # Unity Catalog setup guide
│   ├── DELTA-SHARING.md                # Delta Sharing configuration
│   ├── DEPLOYMENT-TROUBLESHOOTING.md   # Common issues and solutions
│   └── COST-OPTIMIZATION.md            # Cost management strategies
│
└── .gitignore                          # Git ignore rules
```

## Directory Descriptions

### `/infra`
Contains all Bicep Infrastructure as Code files for deploying Azure resources.

**Main template**: `main.bicep`
- Defines parameter inputs
- Calls all module resources
- Returns outputs

**Parameters**: `main.bicepparam`
- Contains parameter values
- Environment-specific settings
- Modify before deployment

**Modules**: `modules/`
- `networking.bicep` (500+ lines)
  - Virtual Network (10.0.0.0/16)
  - 5 subnets for different services
  - Network Security Groups with security rules
  - Service endpoints and delegation
  - Private DNS zones
  - Network configuration for all services

- `databricks.bicep` (100+ lines)
  - Secure Cluster Connectivity (NPIP)
  - VNet injection
  - Premium SKU (for Unity Catalog)
  - Data exfiltration protection

- `storage.bicep` (250+ lines)
  - ADLS Gen2 with hierarchical namespace
  - Private endpoints (Blob, DFS, File)
  - Private DNS zones
  - Containers for Unity Catalog and ML
  - Versioning and soft delete

- `keyvault.bicep` (100+ lines)
  - RBAC-based access
  - Purge protection
  - Private endpoint
  - Private DNS zone

- `acr.bicep` (100+ lines)
  - Premium SKU
  - Private endpoint
  - Security policies
  - Soft delete

- `azureml.bicep` (200+ lines)
  - Application Insights
  - Managed identity
  - Compute cluster
  - Private endpoint

- `ai-foundry.bicep` (150+ lines)
  - Hub workspace
  - Integration with ML services
  - Private endpoint

- `aks.bicep` (200+ lines)
  - Linux nodes (Azure Linux)
  - Private cluster
  - Auto-scaling
  - Security profiles

### `/.azdo`
Azure DevOps pipeline for automated deployment.

- `pipelines/azure-dev.yml`: CI/CD pipeline definition

### `/scripts`
Deployment helper scripts.

- `deploy.sh`: Bash script for Linux/Mac
- `deploy.bat`: PowerShell script for Windows

### `/docs`
Comprehensive documentation for the project.

- Security implementation details
- Step-by-step configuration guides
- Troubleshooting common issues
- Cost optimization strategies

## File Dependencies

```
main.bicep (orchestrator)
├── networking.bicep
│   └── [Creates VNet, subnets, NSGs]
├── databricks.bicep
│   └── [Depends on networking.bicep outputs]
├── storage.bicep
│   ├── [Depends on networking.bicep outputs]
│   └── [Uses vnetId, privateEndpointSubnetId]
├── keyvault.bicep
│   ├── [Depends on networking.bicep outputs]
│   └── [Uses vnetId, privateEndpointSubnetId]
├── acr.bicep
│   ├── [Depends on networking.bicep outputs]
│   └── [Uses vnetId, privateEndpointSubnetId]
├── azureml.bicep
│   ├── [Depends on storage.bicep outputs]
│   ├── [Depends on keyvault.bicep outputs]
│   ├── [Depends on acr.bicep outputs]
│   └── [Depends on networking.bicep outputs]
├── ai-foundry.bicep
│   ├── [Depends on storage.bicep outputs]
│   ├── [Depends on keyvault.bicep outputs]
│   ├── [Depends on acr.bicep outputs]
│   └── [Depends on networking.bicep outputs]
└── aks.bicep
    └── [Depends on networking.bicep outputs]
```

## Parameter Flow

```
main.bicepparam
    ↓
main.bicep (reads parameters)
    ├── projectName → Used in all modules
    ├── location → Used in all modules
    ├── environmentName → Used in all modules
    ├── enableUnityCatalog → databricks.bicep
    ├── enableDeltaSharing → databricks.bicep
    ├── deployAzureML → Conditional azureml.bicep
    ├── deployAIFoundry → Conditional ai-foundry.bicep
    ├── deployAKS → Conditional aks.bicep
    ├── aksNodeCount → aks.bicep
    ├── adminObjectId → keyvault.bicep
    └── tags → All modules
```

## Deployment Flow

```
1. User runs: azd provision
   └── Reads azure.yaml
       └── Calls: az deployment create
           └── Loads: infra/main.bicepparam
               └── Compiles: infra/main.bicep
                   └── Calls modules in order:
                       1. networking.bicep ✓ (no dependencies)
                       2. storage.bicep ✓ (depends on networking)
                       3. keyvault.bicep ✓ (depends on networking)
                       4. acr.bicep ✓ (depends on networking)
                       5. databricks.bicep ✓ (depends on networking)
                       6. azureml.bicep ✓ (depends on storage, kv, acr, networking)
                       7. ai-foundry.bicep ✓ (depends on storage, kv, acr, networking)
                       8. aks.bicep (if deployAKS=true) ✓ (depends on networking)
                           └── Outputs all resource IDs and endpoints
```

## Naming Convention

All resources follow a consistent naming pattern:

```
{resource-type}-{project-name}-{environment}-{optional-suffix}

Examples:
- vnet-secure-db-dev
- dbw-secure-db-dev
- kv-secure-db-dev-abc1234
- st{project}{env}{hash}  (storage accounts have different rules)
- acr{project}{env}{hash}  (ACR has different rules)
```

## Configuration Management

### Environment-Specific Parameters

Create separate parameter files for each environment:

```bash
# Development
infra/main.dev.bicepparam

# Staging
infra/main.staging.bicepparam

# Production
infra/main.prod.bicepparam
```

Example for staging:

```bicep
using './main.bicep'

param environmentName = 'staging'
param location = 'eastus'
param projectName = 'secure-db'
param adminObjectId = '<staging-admin-id>'
param deployAKS = true  # Enable AKS for staging
param aksNodeCount = 5  # More nodes for staging
```

### Variable Substitution

Before deployment, update parameters:

```bash
# Get your admin object ID
ADMIN_ID=$(az ad signed-in-user show --query id -o tsv)

# Update parameter file
sed -i "s/param adminObjectId = ''/param adminObjectId = '$ADMIN_ID'/" infra/main.bicepparam
```

## Resource Tags

All resources are tagged with:

```json
{
  "Environment": "dev|staging|prod",
  "Project": "secure-databricks-azureml",
  "ManagedBy": "Bicep",
  "Purpose": "SecureDataPlatform"
}
```

Custom tags can be added in `main.bicepparam`:

```bicep
param tags = {
  Environment: 'dev'
  Project: 'secure-databricks-azureml'
  ManagedBy: 'Bicep'
  CostCenter: 'Engineering'
  Owner: 'DataTeam'
}
```

## Next Steps

1. **Review**: Check all module files for security settings
2. **Customize**: Modify parameters in `main.bicepparam`
3. **Validate**: Run `az bicep build-params --file infra/main.bicepparam`
4. **Preview**: Run `azd provision --preview`
5. **Deploy**: Run `azd provision`
6. **Configure**: Follow [POST-DEPLOYMENT.md](POST-DEPLOYMENT.md)

---

For more information, see:
- [README.md](README.md) - Project overview
- [POST-DEPLOYMENT.md](POST-DEPLOYMENT.md) - Configuration after deployment
- [docs/SECURITY.md](docs/SECURITY.md) - Security implementation
