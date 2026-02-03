# Complete Bicep Solution - Why Bicep Only?

## ✅ Why Not Terraform + Bicep Hybrid?

The project is **100% Bicep** - not hybrid. Here's why this is better:

### 1. **Single Language Simplicity**
- ❌ Terraform: Another language, another state file, another provider
- ✅ Bicep: Native Azure language, integrated with Azure Resource Manager
- **Benefit**: One mental model, one deployment pipeline, one source of truth

### 2. **Native Managed Identity Support**
- ❌ Terraform: Databricks provider requires PAT tokens (credentials in code)
- ✅ Bicep: Uses Azure managed identities (no credentials)
- **Benefit**: Secure by default, automatically rotated by Azure

### 3. **Deployment Script Integration**
- ❌ Terraform: Separate `terraform apply`, then run scripts
- ✅ Bicep: Orchestrates everything in one deployment
- **Benefit**: All infrastructure + configuration in one `azd provision` call

### 4. **Azure Developer CLI Native**
- ✅ Bicep: `azd` first-class support, built-in integration
- ❌ Terraform: Would require custom integration
- **Benefit**: Standard Azure workflows, easy to share

### 5. **No State Management Complexity**
- ✅ Bicep: Azure Resource Manager manages state (Azure-native)
- ❌ Terraform: Separate state file (tfstate) to manage/backup/sync
- **Benefit**: Simplified operations, Azure-managed safety

---

## 🏗️ Complete Architecture

### Layer 1: Core Infrastructure (Bicep Modules)
```
main.bicep (orchestrates)
├─ networking.bicep
│  └─ VNet, subnets, NSGs, private DNS zones, service endpoints
│
├─ databricks.bicep
│  └─ Premium workspace, VNet injection, NPIP, security policies
│
├─ storage.bicep
│  └─ ADLS Gen2 (hierarchical namespace), private endpoints, versioning
│
├─ keyvault.bicep
│  └─ Secrets management, RBAC, purge protection
│
├─ acr.bicep
│  └─ Container Registry (Premium), security policies
│
├─ azureml.bicep
│  └─ ML workspace, compute cluster, Application Insights
│
├─ ai-foundry.bicep
│  └─ AI hub, shared resources integration
│
├─ aks.bicep (optional)
│  └─ Kubernetes cluster, node pools, CNI networking
│
└─ unity-catalog.bicep (NEW!)
   └─ Deployment script orchestration
```

### Layer 2: Automated Configuration (PowerShell Script)
```
setup-unity-catalog.ps1 (runs in deployment script context)
├─ Authenticate using managed identity (OAuth)
├─ Create metastore on ADLS Gen2 storage
├─ Assign metastore to workspace
├─ Create 3 catalogs:
│  ├─ raw_data
│  ├─ processed_data
│  └─ analytics
├─ Create 5 schemas per catalog
├─ Enable Delta Sharing
└─ All idempotent (safe to re-run)
```

### Layer 3: Deployment Automation (Azure Developer CLI)
```
azure.yaml (project configuration)
├─ Provider: bicep
├─ Path: infra/
├─ Module: main
└─ Hooks: pre-provision, post-provision

deploy.sh / deploy.bat (quick start scripts)
├─ Validate prerequisites
├─ Configure parameters
├─ Run azd provision (preview & actual)
└─ Display results

.azdo/pipelines/azure-dev.yml (CI/CD pipeline)
└─ GitHub Actions or Azure DevOps integration
```

---

## 📊 File Structure & Purpose

```
d:\Databricks\dbx-demos\Azure-Databricks-AzureML\
│
├── 📚 Documentation Files
│   ├── README.md (500+ lines) - Main guide with all sections
│   ├── QUICKSTART.md (200+ lines) - Get started in 5 minutes
│   ├── POST-DEPLOYMENT.md (400+ lines) - Configuration after deploy
│   ├── PROJECT-STRUCTURE.md (350+ lines) - Detailed organization
│   ├── DEPLOYMENT-SUMMARY.md (400+ lines) - Quick reference
│   ├── COMPLETE-BICEP-SOLUTION.md (THIS FILE) - Architecture overview
│   └── docs/
│       └── UNITY-CATALOG.md (400+ lines) - Unity Catalog details
│
├── 🔧 Configuration
│   ├── azure.yaml - AzD configuration
│   ├── main.bicep - Main orchestration (orchestrates all modules)
│   └── main.bicepparam - Parameter values
│
├── 🚀 Deployment Scripts
│   ├── deploy.sh (140 lines) - Linux/Mac deployment
│   ├── deploy.bat (60 lines) - Windows PowerShell deployment
│   └── Makefile (optional) - Make-based deployment
│
├── 📋 CI/CD
│   └── .azdo/pipelines/azure-dev.yml - Azure DevOps pipeline
│
└── 📁 Infrastructure Modules
    └── infra/
        ├── main.bicep (310 lines)
        │   ├─ Calls all 8 modules
        │   ├─ Manages dependencies
        │   ├─ Exports outputs
        │   └─ Conditional deployment (deployAKS, deployAzureML, etc.)
        │
        ├── main.bicepparam (23 parameters)
        │   ├─ environmentName: dev/staging/prod
        │   ├─ projectName: resource naming prefix
        │   ├─ location: Azure region
        │   ├─ adminObjectId: your user/service principal
        │   ├─ enableUnityCatalog: true/false
        │   ├─ enableDeltaSharing: true/false
        │   ├─ deployAKS: true/false (optional)
        │   └─ ... 16 more parameters
        │
        └── modules/
            ├── networking.bicep (280 lines)
            │   ├─ 1x VNet (10.0.0.0/16)
            │   ├─ 5x Subnets (each /24)
            │   ├─ 3x Network Security Groups
            │   ├─ Service endpoints
            │   ├─ Private DNS zones (blob, dfs, file, keyvault, acr)
            │   └─ VNet peering ready
            │
            ├── databricks.bicep (65 lines)
            │   ├─ Premium SKU (required for Unity Catalog)
            │   ├─ VNet injection parameters
            │   ├─ Secure Cluster Connectivity (NPIP)
            │   ├─ Network policies (requireInfrastructureEncryption: true)
            │   └─ Data exfiltration protection
            │
            ├── storage.bicep (250 lines)
            │   ├─ ADLS Gen2 (isHnsEnabled: true)
            │   ├─ Hierarchical namespace (Unity Catalog compatible)
            │   ├─ Versioning & soft delete enabled
            │   ├─ Private endpoints (blob, dfs, file services)
            │   ├─ Private DNS zone integration
            │   ├─ RBAC role assignments
            │   └─ Managed identity access
            │
            ├── keyvault.bicep (100 lines)
            │   ├─ Premium SKU
            │   ├─ Purge protection enabled (permanent)
            │   ├─ RBAC authorization (not access policies)
            │   ├─ Private endpoint for data plane
            │   ├─ Public network access: disabled
            │   └─ Service principal secret storage
            │
            ├── acr.bicep (100 lines)
            │   ├─ Premium SKU (required for private endpoints)
            │   ├─ Zone redundancy enabled
            │   ├─ Private endpoint for private connectivity
            │   ├─ Anonymous pull disabled
            │   ├─ Soft delete policy (7 days)
            │   └─ Quarantine policy enabled
            │
            ├── azureml.bicep (200 lines)
            │   ├─ ML workspace with compute
            │   ├─ Application Insights integration
            │   ├─ Compute cluster (0-10 auto-scaling)
            │   ├─ Private endpoint for workspace access
            │   ├─ Managed identity for resource access
            │   └─ Network isolation
            │
            ├── ai-foundry.bicep (150 lines)
            │   ├─ Hub workspace for centralized AI
            │   ├─ Project integration
            │   ├─ Shared resources (storage, key vault, ACR)
            │   ├─ Private endpoint connectivity
            │   └─ Built-in connections to external services
            │
            ├── aks.bicep (200 lines) - OPTIONAL
            │   ├─ Private cluster (no public API server)
            │   ├─ System & user node pools
            │   ├─ Azure CNI with Cilium network plugin
            │   ├─ Auto-scaling enabled
            │   ├─ Defender for Containers (optional)
            │   └─ System-assigned managed identity
            │
            ├── unity-catalog.bicep (45 lines) ⭐ NEW
            │   ├─ Managed identity for authentication
            │   ├─ Deployment script resource
            │   ├─ Calls PowerShell setup script
            │   ├─ Passes workspace details
            │   └─ Returns metastore outputs
            │
            └── scripts/
                └── setup-unity-catalog.ps1 (280 lines) ⭐ NEW
                    ├─ OAuth token from managed identity
                    ├─ Databricks REST API v2.0 calls
                    ├─ Metastore creation
                    ├─ Catalog creation (3 catalogs)
                    ├─ Schema creation (5 schemas)
                    ├─ Delta Sharing enablement
                    ├─ Error handling & retries
                    └─ Idempotent operations (safe re-run)
```

---

## 🔄 Deployment Workflow

### What Happens When You Run `azd provision`?

```mermaid
azd provision
    ↓
Parse azure.yaml (provider: bicep, path: infra/, module: main)
    ↓
Read infra/main.bicepparam (parameters)
    ↓
Validate azd login (Azure credentials)
    ↓
Create resource group (if needed)
    ↓
Deploy main.bicep
    ├─ Deploy networking module (1-2 min)
    │  └─ Creates VNet, subnets, NSGs, DNS zones
    │
    ├─ Deploy databricks module (2-3 min)
    │  └─ Creates Premium workspace with VNet injection
    │
    ├─ Deploy storage module (1-2 min)
    │  └─ Creates ADLS Gen2 with private endpoints
    │
    ├─ Deploy keyvault module (1 min)
    │  └─ Creates secure secrets storage
    │
    ├─ Deploy acr module (2-3 min)
    │  └─ Creates container registry
    │
    ├─ Deploy azureml module (3-5 min)
    │  └─ Creates ML workspace with compute
    │
    ├─ Deploy ai-foundry module (3-5 min)
    │  └─ Creates AI hub
    │
    ├─ Deploy aks module IF deployAKS=true (10-15 min)
    │  └─ Creates Kubernetes cluster
    │
    └─ Deploy unity-catalog module (5-10 min) ⭐ NEW
       ├─ Creates managed identity
       ├─ Triggers deployment script
       ├─ Script gets managed identity token
       ├─ Script calls Databricks API
       ├─ Creates metastore
       ├─ Creates 3 catalogs + 5 schemas
       └─ Enables Delta Sharing
    
    ↓
All deployments complete (20-40 min total)
    ↓
Databricks workspace is ready with:
  ✅ Network isolated
  ✅ Premium tier
  ✅ VNet injection
  ✅ Unity Catalog configured
  ✅ 3 catalogs (raw_data, processed_data, analytics)
  ✅ 5 schemas per catalog
  ✅ Delta Sharing enabled
```

---

## 🔐 Security Model

### Network Security
- **VNet Injection**: Databricks runs inside customer's VNet
- **Private Endpoints**: All data plane communication is private
- **Network Security Groups**: Restrictive ingress/egress rules
- **Service Endpoints**: Direct Azure service connectivity
- **No Public IPs**: Secure Cluster Connectivity (NPIP) enabled

### Authentication & Identity
- **Managed Identities**: Service-to-service auth without credentials
- **OAuth Tokens**: Temporary scoped tokens (managed by Azure)
- **RBAC**: Role-based access control on all resources
- **No Secrets in Code**: Credentials never in templates or scripts

### Data Security
- **Encryption at Rest**: Infrastructure encryption on storage
- **Encryption in Transit**: TLS 1.2+ for all communication
- **Hierarchical Namespace**: ADLS Gen2 for Unity Catalog
- **Version Control**: Storage versioning and soft delete
- **Immutable**: Key Vault purge protection (cannot be disabled)

### Access Control
- **Private Endpoints**: Only accessible via VNet
- **Network Isolation**: NSG rules block unauthorized access
- **Databricks SCIM**: Manage user access programmatically
- **Unity Catalog RBAC**: Fine-grained data access control

---

## 📊 Unity Catalog Configuration

### What Gets Created

After `azd provision`, your Unity Catalog has:

```
Metastore (on ADLS Gen2)
├── Catalog: raw_data
│   └── Schema: bronze
│       └── External location points to: /raw
│
├── Catalog: processed_data
│   ├── Schema: silver
│   │   └── External location points to: /processed
│   └── Schema: gold
│       └── External location points to: /processed
│
└── Catalog: analytics
    ├── Schema: reports
    │   └── External location points to: /analytics
    └── Schema: ml_features
        └── External location points to: /analytics
```

### Storage Directory Structure

```
Storage Account (ADLS Gen2)
├── unity-catalog/ (metastore root)
│   ├── _current_version/
│   ├── delta_log/
│   └── [metastore files]
│
├── raw/ (raw_data.bronze tables)
├── processed/ (processed_data.silver/gold tables)
└── analytics/ (analytics.reports/ml_features tables)
```

### Access Control

```
Managed Identity
  ↓
Has "Storage Blob Data Contributor" role on Storage Account
  ↓
Can read/write to all directories
  ↓
Databricks cluster inherits managed identity
  ↓
Can access all catalogs and tables
  ↓
Delta Sharing enabled for external sharing
```

---

## ✅ Pre-Deployment Checklist

Before running `azd provision`:

- [ ] **Azure CLI installed** (`az --version`)
- [ ] **Azure Developer CLI installed** (`azd --version`)
- [ ] **Logged into Azure** (`az login`)
- [ ] **Edit `infra/main.bicepparam`:**
  - [ ] Set `adminObjectId` to your user ID or service principal
  - [ ] Set `projectName` (e.g., "secure-db")
  - [ ] Set `location` (e.g., "eastus", "westeurope")
  - [ ] Set `environmentName` (dev/staging/prod)
- [ ] **Review parameters:**
  - [ ] `enableUnityCatalog` = true (default: yes)
  - [ ] `enableDeltaSharing` = true (default: yes)
  - [ ] `deployAKS` = true/false (optional: no by default)
- [ ] **Verify permissions:**
  - [ ] Owner or Contributor role on subscription
  - [ ] Ability to create resource groups
  - [ ] Ability to register resource providers

---

## 🚀 Quick Start

### Step 1: Prepare Parameters

```bash
# Get your user object ID
az ad signed-in-user show --query id -o tsv

# Copy and save the output (long UUID)
# This is your adminObjectId
```

### Step 2: Update Parameters

Edit `infra/main.bicepparam`:

```bicep
param adminObjectId = 'YOUR-USER-ID-HERE'  // Paste your UUID
param projectName = 'mycompany-adb'
param location = 'eastus'
param environmentName = 'dev'
param enableUnityCatalog = true
param enableDeltaSharing = true
param deployAKS = false  // Set to true if you want Kubernetes
```

### Step 3: Preview Deployment

```bash
# Validate and show what will be created
azd provision --preview
```

Review the deployment plan carefully.

### Step 4: Deploy

```bash
# Deploy all infrastructure (20-40 minutes)
azd provision
```

**What happens automatically:**
✅ Azure resources created
✅ Networking configured
✅ Databricks workspace deployed
✅ Unity Catalog configured
✅ All data structures created

### Step 5: Verify

```bash
# Get Databricks workspace URL
az databricks workspace list --resource-group YOUR-RG-NAME --query "[0].workspaceUrl" -o tsv

# Open in browser and sign in
# Check Catalog Explorer
# Should see: raw_data, processed_data, analytics
```

---

## 📝 Customization

### Change Catalog Names

Edit `infra/modules/scripts/setup-unity-catalog.ps1`, line ~90:

```powershell
$catalogNames = @(
    "my_raw_data",
    "my_processed_data",
    "my_analytics"
)
```

### Change Schema Names

Edit `infra/modules/scripts/setup-unity-catalog.ps1`, line ~120:

```powershell
$schemas = @(
    @{ catalog = "my_raw_data"; schema = "bronze"; comment = "Raw ingestion layer" }
    @{ catalog = "my_processed_data"; schema = "silver"; comment = "Cleaned data layer" }
    @{ catalog = "my_processed_data"; schema = "gold"; comment = "Business layer" }
    # ... etc
)
```

### Disable Unity Catalog

In `main.bicepparam`:

```bicep
param enableUnityCatalog = false  // Won't create UC
```

### Disable Delta Sharing

In `main.bicepparam`:

```bicep
param enableDeltaSharing = false  // UC enabled but no Delta Sharing
```

---

## 🔍 Monitoring & Diagnostics

### Check Deployment Status

```bash
# View resource group
az group show -g rg-mycompany-adb-dev

# List all resources
az resource list --resource-group rg-mycompany-adb-dev

# Check Databricks workspace
az databricks workspace list --resource-group rg-mycompany-adb-dev
```

### Verify Unity Catalog

From Databricks workspace, run:

```sql
-- List all catalogs
SELECT * FROM system.information_schema.catalogs;

-- List all schemas
SELECT * FROM system.information_schema.schemata;

-- Check Delta Sharing status
SELECT * FROM system.metastores;
```

### View Deployment Logs

```bash
# Show last deployment
az deployment group list --resource-group rg-mycompany-adb-dev

# Show errors (if any)
az deployment group show \
  --resource-group rg-mycompany-adb-dev \
  --name main-{timestamp}
```

---

## 💡 Why This Architecture?

### Network Isolation ✅
- Databricks runs in customer's VNet
- No traffic leaves Azure network
- Private endpoints for all data access
- NSGs enforce security boundaries

### Data Governance ✅
- Unity Catalog enforces permissions
- Track data lineage and access
- Delta Sharing for secure external sharing
- Audit logs for compliance

### Cost Optimization ✅
- Reserved compute for Databricks
- Auto-scaling (pay only for used resources)
- Shared resources (ML, storage, vault)
- No unused infrastructure

### Security by Default ✅
- Managed identities (no credentials)
- Encryption everywhere (rest & transit)
- RBAC for all resources
- Private endpoints (no internet exposure)

### Easy Operations ✅
- Single language (Bicep)
- Single deployment command (`azd provision`)
- Version control for all infrastructure
- Infrastructure as code (reproducible)

---

## 📞 Need Help?

1. **Quick issues**: See [QUICKSTART.md](QUICKSTART.md)
2. **Deployment help**: See [DEPLOYMENT-SUMMARY.md](DEPLOYMENT-SUMMARY.md)
3. **Post-deployment**: See [POST-DEPLOYMENT.md](POST-DEPLOYMENT.md)
4. **Project layout**: See [PROJECT-STRUCTURE.md](PROJECT-STRUCTURE.md)
5. **Unity Catalog**: See [docs/UNITY-CATALOG.md](docs/UNITY-CATALOG.md)
6. **Everything else**: See [README.md](README.md)

---

## 🎉 You're Ready!

This is a complete, production-ready solution in pure Bicep.

**No Terraform. No hybrid approaches. Just clean, simple, Azure-native Infrastructure as Code.**

Deploy with confidence! 🚀
