# 🔗 Core Integration

These notebooks demonstrate the foundational connectivity patterns between Azure Databricks and Azure Machine Learning. Master these before moving to advanced workflows.

## 📚 Notebooks

### 1. **Complete_Databricks_AzureML_Integration.ipynb**
**Purpose:** Complete reference for all integration capabilities from Databricks

**What you'll learn:**
- Install and configure Azure ML SDK v2 in Databricks
- Authenticate with DefaultAzureCredential
- Submit training jobs to AzureML compute
- Register models from DBFS to AzureML
- Trigger AutoML jobs from Databricks
- Log metrics and track experiments
- Create pipelines that orchestrate both services

**Use cases:**
- Data scientists working primarily in Databricks notebooks
- Teams that want to leverage AzureML's managed compute
- Hybrid workflows that need both platforms

**Time to complete:** 45-60 minutes

---

### 2. **AzureML_SDK_v2_Complete_Integration.ipynb**
**Purpose:** Deep dive into Azure ML SDK v2 features from Databricks

**What you'll learn:**
- SDK v2 architecture and capabilities
- Command jobs and component creation
- Pipeline construction and execution
- Model registration and versioning
- Environment and compute management
- Advanced MLflow integration

**Use cases:**
- Building production ML pipelines
- Teams standardizing on SDK v2
- Complex multi-step workflows

**Time to complete:** 60-90 minutes

---

### 3. **Databricks_to_AzureML_Connection.ipynb**
**Purpose:** Call AzureML managed online endpoints from Databricks

**What you'll learn:**
- Authenticate to AzureML endpoints (managed identity/service principal)
- Real-time model scoring from Databricks
- Handle authentication tokens
- Error handling and retries
- Performance optimization

**Use cases:**
- Scoring data in Databricks using AzureML-hosted models
- Real-time inference within Spark jobs
- Hybrid model deployment strategies

**Time to complete:** 30-45 minutes

**Direction:** Databricks → AzureML

---

### 4. **AzureML_to_Databricks_Data_Access.ipynb**
**Purpose:** Call Databricks model serving endpoints from AzureML

**What you'll learn:**
- Authenticate using AAD tokens
- Call Databricks model serving REST API
- Handle responses and errors
- Network connectivity requirements

**Use cases:**
- AzureML pipelines that need Databricks-hosted models
- Testing Databricks endpoints from AzureML compute
- Cross-service model comparison

**Time to complete:** 30-45 minutes

**Direction:** AzureML → Databricks

---

### 5. **Key Vault Integration Testing**

Platform-specific notebooks for testing secure credential management:

#### **AzureML_KeyVault_Integration_Test.ipynb**
**Purpose:** Test Azure Machine Learning workspace integration with Key Vault using managed identity

**What you'll learn:**
- Authenticate to Key Vault from AzureML using DefaultAzureCredential
- Store and retrieve secrets using RBAC permissions (Key Vault Secrets User/Officer)
- Validate MLClient connectivity and workspace access
- Test read/write operations with comprehensive error handling
- Integrate Key Vault secrets with AzureML datastores

**Use cases:**
- Secure storage of API keys and connection strings for AzureML training jobs
- Production deployments requiring centralized secret management
- Audit and compliance requirements for secret access

**Time to complete:** 20-30 minutes

**Run as Job:** 📂 [Azure ML Job](jobs/azureml-job/) - Execute on Azure ML compute using Papermill

---

#### **Databricks_KeyVault_Integration_Test.ipynb**
**Purpose:** Test Databricks workspace integration with Key Vault using secret scopes

**What you'll learn:**
- Access Key Vault secrets via Databricks secret scopes (Access Policies model)
- List and retrieve secrets using dbutils.secrets
- Validate secret scope configuration and permissions
- Connect to Azure ML workspace using scope-backed credentials
- Test direct Key Vault access and secret redaction

**Use cases:**
- Databricks notebooks requiring secure credential access
- Secret management for Spark jobs and workflows
- Cross-service authentication (Databricks → Azure ML, Key Vault)

**Time to complete:** 20-30 minutes

**Run as Job:** 📂 [Databricks Job](jobs/databricks-job/) - Execute on Databricks clusters with secret scope parameters

---

**Comparison:**
- **Azure ML**: RBAC-based access, managed identity authentication, direct Key Vault SDK
- **Databricks**: Access Policies, secret scope abstraction, dbutils.secrets API
- **Setup Guide:** 📚 [Job Setup Guide](jobs/) - Platform comparison and quick start

---

## 🎯 Integration Patterns

### Pattern 1: Data Science in Databricks, Training in AzureML
```
Databricks (feature engineering) → AzureML (training + deployment)
```
**Use:** `Complete_Databricks_AzureML_Integration.ipynb`

### Pattern 2: Training in AzureML, Inference in Databricks
```
AzureML (model hosting) → Databricks (scoring at scale)
```
**Use:** `Databricks_to_AzureML_Connection.ipynb`

### Pattern 3: Hybrid Model Serving
```
Databricks ↔ AzureML (models deployed on both platforms)
```
**Use:** Both connectivity notebooks

### Pattern 4: Secure Secret Management
```
Key Vault → AzureML + Databricks (centralized credential management)
```
**Use:** `AzureML_KeyVault_Integration.ipynb`

---

## 🔐 Authentication Methods

All notebooks support multiple authentication patterns:

1. **Managed Identity (Recommended for Production)**
   - Configured automatically on Databricks clusters
   - No secrets to manage
   - Best security posture

2. **Service Principal**
   - Environment variables: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_CLIENT_SECRET`
   - Use Azure Key Vault or Databricks secrets
   - Good for CI/CD pipelines

3. **Azure CLI (Development Only)**
   - `az login` from local machine
   - Not suitable for production
   - Quick testing and development

---

## 📋 Prerequisites

### Azure Resources
- ✅ Azure Databricks workspace (Premium tier recommended)
- ✅ Azure Machine Learning workspace
- ✅ Azure Key Vault (for secret management)
- ✅ Network connectivity (private or public)
- ✅ RBAC roles: Contributor or AzureML Data Scientist
- ✅ Key Vault roles: Key Vault Secrets User (read) or Key Vault Secrets Officer (read/write)

### Python Packages (install in Databricks)
```bash
%pip install azure-ai-ml azure-identity azure-keyvault-secrets mlflow
```

### Configuration Values
You'll need to know:
- Subscription ID
- Resource group name
- AzureML workspace name
- Databricks workspace URL
- Compute cluster names

---

## 🔍 Troubleshooting Common Issues

### Issue: `DefaultAzureCredential failed to retrieve a token`
**Solution:** Ensure cluster has managed identity assigned or set service principal environment variables

### Issue: `Compute target not found`
**Solution:** Create compute cluster in AzureML Studio first, then reference exact name

### Issue: `Network connectivity error`
**Solution:** Check private endpoint configuration and DNS resolution

### Issue: `Model not found in registry`
**Solution:** Verify model registration completed successfully and use correct model name/version

### Issue: `Access denied to Key Vault (403)`
**Solution:** Ensure identity has RBAC role assigned (Key Vault Secrets User or Key Vault Secrets Officer)

### Issue: `Databricks secret scope not found`
**Solution:** Create Key Vault-backed secret scope at `https://<databricks-instance>#secrets/createScope`

---

## 🎓 Learning Path

1. **Start:** `Complete_Databricks_AzureML_Integration.ipynb` (get overview)
2. **Deep dive:** `AzureML_SDK_v2_Complete_Integration.ipynb` (SDK mastery)
3. **Connectivity:** Both direction-specific notebooks (understand patterns)
4. **Next:** Move to [ML Workflows](../03-ml-workflows/) for end-to-end scenarios

---

## 📚 Additional Resources

- [Azure ML SDK v2 Documentation](https://learn.microsoft.com/azure/machine-learning/)
- [Databricks Azure ML Integration](https://learn.microsoft.com/azure/databricks/)
- [Managed Identity Best Practices](https://learn.microsoft.com/azure/databricks/security/aad-token)
- [Azure Key Vault RBAC Guide](https://learn.microsoft.com/azure/key-vault/general/rbac-guide)
- [Databricks Secret Scopes](https://learn.microsoft.com/azure/databricks/security/secrets/secret-scopes)
- [Azure ML Security Best Practices](https://learn.microsoft.com/azure/machine-learning/concept-enterprise-security)

---

[← Back to Quickstart](../01-quickstart/) | [Next: ML Workflows →](../03-ml-workflows/)
