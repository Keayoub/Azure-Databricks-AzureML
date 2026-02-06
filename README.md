# Secure Azure Databricks with Azure ML and AI Foundry

Complete Infrastructure as Code (IaC) deployment for a secure, enterprise-grade data and AI platform on Azure.

## 🎯 Quick Start (5 Minutes)

### Prerequisites Installation (1 minute)

All prerequisites in one script - works on Windows, macOS, and Linux!

**Requirements:** PowerShell 7.0+ ([download here](https://learn.microsoft.com/powershell/scripting/install/installing-powershell))

```powershell
# Run the universal installation script
pwsh ./scripts/install-prerequisites.ps1

# Or upgrade existing tools
pwsh ./scripts/install-prerequisites.ps1 -Upgrade
```

This installs:
- ✅ Python 3.7+
- ✅ Azure CLI
- ✅ Azure Developer CLI
- ✅ Databricks CLI
- ✅ Required Python dependencies

### Deployment (4 minutes)

```bash
# 1. Get your object ID
az ad signed-in-user show --query id -o tsv

# 2. Edit infra/main.bicepparam and set adminObjectId

# 3. Set your Databricks Account ID (one-time setup)
# Get it from: https://accounts.azuredatabricks.net
azd env set DATABRICKS_ACCOUNT_ID "your-account-id"

# 4. Deploy (Bicep + Terraform Unity Catalog automatically)
azd provision
```

**Total time: 15-30 minutes** (infrastructure deployment)

> **Note:** Your Databricks Account ID is available at <https://accounts.azuredatabricks.net> in the URL or Account Settings. This is a one-time configuration - Azure Developer CLI stores it for all future deployments.

## 🏗️ What Gets Deployed

### Infrastructure

- **Virtual Network** with private subnets
- **Private Endpoints** for all data services
- **Network Security Groups** with restrictive rules
- **Storage Account** (ADLS Gen2) with Zone-Redundant Storage

### Services

- **Azure Databricks** (Premium, VNet injection, Secure Cluster Connectivity)
- **Azure Machine Learning** workspace
- **Azure AI Foundry** hub
- **Azure Key Vault** (Premium with purge protection)
- **Container Registry** (Premium)
- **Azure Kubernetes Service** (optional)

### Data Governance

- **Unity Catalog** with 3 LoB catalogs per environment
- **Medallion Architecture**: Bronze, Silver, Gold schemas
- **Delta Sharing** enabled
- **Environment-based isolation**: dev, QA, prod

## 📊 Unity Catalog Structure

```text
Metastore (Canada East, 1 per region)
├── dev_lob_team_1
│   ├── bronze (raw data)
│   ├── silver (cleaned data)
│   └── gold (analytics-ready)
├── dev_lob_team_2
└── dev_lob_team_3
```

Switch environment by changing `environmentName` in parameters.

## 🔒 Security Features

✅ **Network Isolation**

- VNet with private subnets
- Network Security Groups
- Private endpoints (no public internet exposure)

✅ **Data Protection**

- Databricks Secure Cluster Connectivity
- Storage encryption
- TLS 1.2+ for all connections

✅ **Identity & Access**

- Azure Entra ID integration
- RBAC on all resources
- Managed identities for service-to-service auth

✅ **Compliance**

- Infrastructure encryption
- Audit logging
- Geo-redundant storage

## 📋 Prerequisites

- Python 3.7+
- Azure CLI (v2.50+)
- Azure Developer CLI (v1.10+)
- Databricks CLI
- Owner or Contributor role on Azure subscription

**👉 Install all prerequisites with one command** (see Quick Start above)

## 📁 Project Structure

```text
infra/
├── main.bicep              # Main orchestration
├── main.bicepparam         # Parameters (edit this)
└── modules/
    ├── networking.bicep
    ├── databricks.bicep
    ├── storage.bicep
    ├── keyvault.bicep
    ├── acr.bicep
    ├── azureml.bicep
    ├── ai-foundry.bicep
    ├── aks.bicep
    ├── unity-catalog.bicep
    └── scripts/
        └── setup-unity-catalog.ps1

docs/
├── TERRAFORM-AZD-INTEGRATION.md  # Two-phase deployment guide
└── SECURITY-AUDIT.md             # Security & networking audit

terraform/
├── README.md               # Terraform-specific guide
├── modules/
│   ├── databricks-uc-metastore/    # UC metastore setup
│   ├── databricks-uc-catalogs/     # Catalogs & schemas
│   └── databricks-uc-volumes/      # External volumes
└── environments/
    ├── dev.tf              # Terraform configuration
    ├── variables.tf        # Input variables
    ├── outputs.tf          # Output values
    └── dev.tfvars          # Environment-specific values (dev)
```

## 📚 Deployment Architecture

```
┌─────────────────────────────────────────────────┐
│         Azure Subscription                      │
├─────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────┐  │
│  │  Bicep IaC (Azure Infrastructure)        │  │
│  │  ├─ Resource Groups (4)                  │  │
│  │  ├─ Networking (VNet, NSG, Endpoints)    │  │
│  │  ├─ Databricks Workspace                 │  │
│  │  ├─ Azure ML Workspace                   │  │
│  │  ├─ AI Foundry Hub                       │  │
│  │  └─ Monitoring (Log Analytics)           │  │
│  └──────────────────────────────────────────┘  │
│           ↓ Outputs to                         │
│  ┌──────────────────────────────────────────┐  │
│  │  Terraform IaC (Unity Catalog Layer)      │  │
│  │  ├─ UC Metastore                         │  │
│  │  ├─ Catalogs & Schemas                   │  │
│  │  ├─ Volumes & Permissions                │  │
│  │  └─ Security & Access Control            │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

## 🚀 Deployment Time

Bicep infrastructure: **15-30 minutes**
Terraform UC layer: **5-10 minutes**

## 📖 Documentation

- [Bicep Deployment Guide](./docs/DEPLOYMENT.md)
- [Unity Catalog Setup (Terraform)](./terraform/README.md) ← **New!**
- [Post-Deployment Configuration](./docs/POST-DEPLOYMENT.md)
- [Project Structure](./docs/PROJECT-STRUCTURE.md)


## 🔧 Common Commands

### Bicep Infrastructure Deployment

```bash
# Install prerequisites (all platforms)
pwsh ./scripts/install-prerequisites.ps1

# Validate infrastructure
az bicep build-params --file infra/main.bicepparam

# Preview deployment
azd provision --preview

# Deploy
azd provision

# Check deployment status
az deployment sub show -n databricks-azureml-iac
```

### Terraform Unity Catalog Deployment

```bash
# Navigate to Terraform directory
cd terraform/environments

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan -var-file=dev.tfvars

# Deploy UC infrastructure
terraform apply -var-file=dev.tfvars

# Get outputs
terraform output -json

# Destroy UC infrastructure (careful!)
terraform destroy -var-file=dev.tfvars
```

### Databricks Setup

```bash
# Configure Databricks CLI
databricks configure --token

# Verify workspace connection
databricks workspace list

# Run post-deployment setup
.\infra\scripts\deployment\install-prerequisites.ps1
```


## 📞 Support

For issues or questions:

1. Check [POST-DEPLOYMENT.md](./docs/POST-DEPLOYMENT.md)
2. Review deployment logs: `azd provision --debug`
3. Check Azure Portal for resource-specific errors

## 📄 License

This project is provided as-is for reference and educational purposes.
