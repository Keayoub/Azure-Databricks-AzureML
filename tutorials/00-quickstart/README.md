# 🚀 Quickstart Tutorials

**Start here!** These notebooks provide quick overview and hands-on testing to get you up and running with Databricks + Azure ML integration.

## 📚 Notebooks

### 1. **00_Integration_Guide.ipynb**
**Purpose:** Complete index and overview of all integration patterns

**What you'll learn:**
- Available integration notebooks and their purposes
- When to use each notebook
- Prerequisites and setup guidance
- Quick links to specific scenarios

**Time to complete:** 5-10 minutes (reading)

---

### 2. **QUICKSTART_Test_AzureML_Models.ipynb**
**Purpose:** Quick hands-on test of calling AzureML models from Databricks

**What you'll learn:**
- Connect to AzureML from Databricks
- Call deployed AzureML endpoints
- Test model inference in real-time
- Basic error handling and troubleshooting

**Time to complete:** 15-20 minutes

**Prerequisites:**
- ✅ Databricks workspace (running cluster)
- ✅ AzureML workspace with deployed endpoint
- ✅ Appropriate authentication (managed identity or token)

---

## 🎯 What's Next?

After completing these quickstart notebooks:

1. **Learn Core Integration** → Go to [02-core-integration](../02-core-integration/)
   - Deep dive into SDK setup
   - Authentication patterns
   - Bi-directional connectivity

2. **Build ML Workflows** → Go to [03-ml-workflows](../03-ml-workflows/)
   - Feature engineering in Databricks
   - Training pipelines in AzureML
   - Real-time and batch inference

3. **Setup MLOps** → Go to [04-mlops-orchestration](../04-mlops-orchestration/)
   - Automated pipelines
   - CI/CD integration
   - Production orchestration

---

## 🔍 Quick Check - Are You Ready?

Before starting, ensure you have:

- [ ] Access to Azure Databricks workspace
- [ ] Access to Azure Machine Learning workspace  
- [ ] Appropriate permissions (Contributor or higher)
- [ ] Network connectivity between services (if using private endpoints)
- [ ] Python packages: `azure-ai-ml`, `azure-identity`, `mlflow`

**Need help with setup?** Check the [main docs](../docs/) for detailed infrastructure deployment guides.

---

## 🆘 Getting Help

- **Deployment issues:** See [infrastructure guides](../../infra/)
- **Authentication errors:** Check [core integration](../02-core-integration/) notebooks
- **Networking problems:** Review [enterprise reference](../06-enterprise-reference/)

---

[← Back to Main](../README.md) | [Next: Core Integration →](../02-core-integration/)
