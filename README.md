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
- ✅ Terraform
- ✅ Databricks CLI
- ✅ Required Python dependencies

### Deployment (4 minutes)

```bash
# 1. Validate deployment readiness
pwsh infra/scripts/validate.ps1

# 2. Get your object ID for Key Vault access
az ad signed-in-user show --query id -o tsv

# 3. Edit infra/main.bicepparam and set adminObjectId

# 4. Set your Databricks Account ID (one-time setup)
# Get it from: https://accounts.azuredatabricks.net
$env:DATABRICKS_ACCOUNT_ID = "your-account-id"

# 5. Deploy (Bicep + Terraform Unity Catalog automatically)
azd provision
azd deploy
```

**Total time: 15-30 minutes** (infrastructure deployment)

### Documentation

**Start Here:**

- 🗺️ **[PROJECT-STRUCTURE.md](docs/PROJECT-STRUCTURE.md)** - Complete documentation map and navigation guide
- ⚡ **[QUICKSTART.md](QUICKSTART.md)** - Get started in 5 minutes
- 📋 **[DEPLOYMENT-PROCESS.md](docs/DEPLOYMENT-PROCESS.md)** - Complete deployment workflow and troubleshooting

**Terraform Guides:**

- 🏗️ **[terraform/TERRAFORM-README.md](terraform/TERRAFORM-README.md)** - Terraform structure, architecture, and quick start
- 🔍 **[terraform/INDEX.md](terraform/INDEX.md)** - Quick navigation and reference
- [Terraform Quick Start](terraform/docs/TERRAFORM-QUICK-START.md)
- [Terraform Quick Reference](terraform/docs/TERRAFORM-QUICK-REFERENCE.md)

**Module Documentation:**

- [Unity Catalog Catalogs Module](terraform/modules/adb-uc-catalogs/README.md)
- [Unity Catalog Volumes Module](terraform/modules/adb-uc-volumes/README.md)

**Project Information:**

- 📊 **[ENHANCEMENTS-SUMMARY.md](docs/ENHANCEMENTS-SUMMARY.md)** - What was improved in this project
- 🔒 [SECURITY-AUDIT.md](docs/SECURITY-AUDIT.md) - Security and compliance details

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

## 🏗️ Two-Phase Deployment Architecture

This project uses a **two-phase, separated-by-design** architecture:

### Phase 1: Infrastructure (Bicep)

Deploys **Azure resources** in `infra/`:
- Virtual Networks and security groups
- Storage accounts and Key Vault
- Databricks workspace (Premium, VNet-injected)
- Azure ML and AI Foundry services
- Private endpoints for all data services

**Command:** `azd provision`

**Output:** Bicep outputs fed automatically to Phase 2

### Phase 2: Configuration (Terraform)

Deploys **Databricks account-level configuration** in `terraform/`:
- Unity Catalog metastore
- Catalogs, schemas, and volumes
- External locations and credentials
- Workspace-to-metastore assignment

**Command:** `azd deploy` (auto-triggered)

**Input:** Bicep outputs (workspace URL, storage account, region)

### Why Two Phases?

| Layer | Owner | Tool | Scope |
|-------|-------|------|-------|
| **Infrastructure** | Azure/Cloud admin | Bicep | Azure resources (compute, network, storage) |
| **Configuration** | Databricks admin | Terraform | Databricks account objects (catalog, metastore) |

This separation ensures:
- ✅ **Clear ownership**: Azure ops vs. Databricks admins
- ✅ **Reusability**: Terraform works with any Databricks workspace
- ✅ **Team collaboration**: Different teams manage different layers
- ✅ **Repeatability**: Run either layer independently

### Terraform Structure

```
terraform/
├── metastore/              # Phase 1.5: Create UC metastore
│   ├── main.tf             # Account-level metastore setup
│   ├── variables.tf        # Input variables
│   ├── outputs.tf          # Outputs (metastore ID)
│   └── (terraform.tfvars)  # Generated by postprovision
│
└── environments/           # Phase 2: Deploy UC components
    ├── main.tf             # Catalogs, schemas, volumes
    ├── variables.tf        # Input variables
    ├── outputs.tf          # Outputs (catalog IDs)
    └── (terraform.tfvars)  # Generated by postdeploy
```

**Key Design:** Both Terraform layers automatically receive variables from Bicep outputs via deployment scripts. No manual configuration needed!

**For detailed documentation:** See [Deployment Process](./docs/DEPLOYMENT-PROCESS.md)

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

- [Terraform + azd Integration Guide](./docs/TERRAFORM-AZD-INTEGRATION.md) - Two-phase deployment
- [Security & Private Connectivity Audit](./docs/SECURITY-AUDIT.md) - Network security details
- [Terraform Unity Catalog Setup](./terraform/README.md) - UC configuration guide


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

1. Check [Terraform + azd Integration Guide](./docs/TERRAFORM-AZD-INTEGRATION.md)
2. Review deployment logs: `azd provision --debug`
3. Check Azure Portal for resource-specific errors

## 📄 License

This project is provided as-is for reference and educational purposes.
