# Secure Azure Databricks with Azure ML and AI Foundry

Complete Infrastructure as Code (IaC) deployment for a secure, enterprise-grade data and AI platform on Azure.

## 🎯 Quick Start

### 1. Get Your Object ID
```bash
az ad signed-in-user show --query id -o tsv
```

### 2. Configure Deployment

Edit `infra/main.bicepparam`:
```bicep
param environmentName = 'dev'
param location = 'canadaeast'
param adminObjectId = '<your-object-id>'
```

### 3. Deploy
```bash
azd provision
```

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

```
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

- Azure CLI (v2.50+)
- Azure Developer CLI (v1.10+)
- Owner or Contributor role on Azure subscription

## 📁 Project Structure

```
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
├── DEPLOYMENT.md           # Deployment instructions
├── UNITY-CATALOG.md        # Catalog configuration
└── POST-DEPLOYMENT.md      # Post-deployment steps
```

## 🚀 Deployment Time

Typical deployment: **15-30 minutes**

## 📖 Documentation

- [Deployment Guide](./docs/DEPLOYMENT.md)
- [Unity Catalog Setup](./docs/UNITY-CATALOG.md)
- [Post-Deployment Configuration](./docs/POST-DEPLOYMENT.md)
- [Project Structure](./docs/PROJECT-STRUCTURE.md)

## 🔧 Common Commands

```bash
# Validate Bicep
az bicep build-params --file infra/main.bicepparam

# Preview deployment
azd provision --preview

# Deploy
azd provision

# Clean up
az group delete --name <resource-group-name>
```

## 📞 Support

For issues or questions:
1. Check [POST-DEPLOYMENT.md](./docs/POST-DEPLOYMENT.md)
2. Review deployment logs: `azd provision --debug`
3. Check Azure Portal for resource-specific errors

## 📄 License

This project is provided as-is for reference and educational purposes.
