# 📚 Databricks + Azure ML Integration Tutorials

Welcome to the comprehensive tutorial collection for integrating **Azure Databricks** with **Azure Machine Learning** and **AI Foundry**. These tutorials demonstrate enterprise-grade patterns for building production ML platforms on Azure.

## 🎯 What You'll Learn

- **Bi-directional integration** between Databricks and Azure ML
- **End-to-end ML workflows** from feature engineering to deployment
- **MLOps automation** with pipelines and orchestration
- **Unity Catalog** for data governance and model management
- **Enterprise security patterns** for production deployments
- **AI Foundry integration** for generative AI capabilities

---

## 🗂️ Tutorial Organization

Tutorials are organized by **priority and feature category** to help you navigate from beginner to advanced topics:

### 🚀 [01 - Quickstart](./01-quickstart/)
**Start here!** Quick overview and hands-on testing
- Integration guide and overview
- Test AzureML models from Databricks
- **Time:** 15-30 minutes
- **Level:** Beginner

### 🔗 [02 - Core Integration](./02-core-integration/)
Foundation connectivity patterns and SDK usage
- Complete Databricks ↔ Azure ML integration
- SDK v2 deep dive
- Authentication and networking
- **Time:** 2-3 hours
- **Level:** Beginner to Intermediate

### 🤖 [03 - ML Workflows](./03-ml-workflows/)
Complete ML lifecycle: data → training → inference
- Feature engineering in Databricks
- Training pipelines with Azure ML
- Batch and real-time inference
- Model testing and validation
- **Time:** 3-4 hours
- **Level:** Intermediate

### ⚙️ [04 - MLOps Orchestration](./04-mlops-orchestration/)
Production automation and CI/CD
- AzureML pipeline orchestration
- PowerShell automation scripts
- Multi-environment deployment
- CI/CD integration patterns
- **Time:** 3-4 hours
- **Level:** Intermediate to Advanced

### 🗄️ [05 - Unity Catalog](./05-unity-catalog/)
Data governance and compliance
- Unity Catalog architecture
- Feature store with governance
- Model registry and lineage
- Access controls and auditing
- **Time:** 2-3 hours
- **Level:** Intermediate to Advanced

### 🏢 [06 - Enterprise Reference](./06-enterprise-reference/)
Production-grade enterprise architecture
- Network isolation and security
- Multi-region deployment
- Cost optimization strategies
- Compliance frameworks
- Monitoring and observability
- **Time:** 3-4 hours
- **Level:** Advanced

---

## 📖 Quick Navigation

### By Use Case

| Use Case | Start Here |
|----------|-----------|
| I want to test the integration quickly | [01-quickstart](./01-quickstart/) |
| I need to call AzureML from Databricks | [02-core-integration](./02-core-integration/) |
| I want to build an end-to-end ML pipeline | [03-ml-workflows](./03-ml-workflows/) |
| I need to automate ML workflows | [04-mlops-orchestration](./04-mlops-orchestration/) |
| I need data governance and compliance | [05-unity-catalog](./05-unity-catalog/) |
| I'm deploying for enterprise production | [06-enterprise-reference](./06-enterprise-reference/) |

### By Role

| Role | Recommended Path |
|------|------------------|
| **Data Scientist** | 01 → 02 → 03 → 05 |
| **ML Engineer** | 01 → 02 → 03 → 04 |
| **Platform Engineer** | 02 → 04 → 05 → 06 |
| **Architect** | 02 → 05 → 06 |
| **DevOps Engineer** | 04 → 06 |

### By Integration Direction

| Direction | Notebooks |
|-----------|-----------|
| **Databricks → Azure ML** | `Complete_Databricks_AzureML_Integration.ipynb`<br/>`AzureML_SDK_v2_Complete_Integration.ipynb` |
| **Azure ML → Databricks** | `AzureML_to_Databricks_Data_Access.ipynb` |
| **Databricks → Azure ML (Inference)** | `Databricks_to_AzureML_Connection.ipynb` |
| **Bi-directional Orchestration** | `04_MLOps_Orchestration.ipynb`<br/>`10_DBX_AML_Integration_Guide.ipynb` |

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Azure Subscription                            │
│                                                                  │
│  ┌──────────────────┐         ┌─────────────────┐              │
│  │  Azure Databricks│◄────────┤   Azure ML      │              │
│  │  - Spark ETL     │         │   - Training    │              │
│  │  - Feature Eng   │         │   - Endpoints   │              │
│  │  - Unity Catalog │◄───────►│   - Pipelines   │              │
│  │  - Model Serving │         │   - Experiments │              │
│  └────────┬─────────┘         └────────┬────────┘              │
│           │                            │                        │
│           └──────────┬─────────────────┘                        │
│                      ↓                                          │
│            ┌──────────────────┐                                │
│            │  AI Foundry Hub  │                                │
│            │  - LLMs          │                                │
│            │  - Prompt Flow   │                                │
│            └──────────────────┘                                │
│                      ↓                                          │
│            ┌──────────────────┐                                │
│            │  Shared Services │                                │
│            │  - ADLS Gen2     │                                │
│            │  - Key Vault     │                                │
│            │  - Container Reg │                                │
│            │  - Networking    │                                │
│            └──────────────────┘                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🚦 Getting Started

### Prerequisites

#### Azure Resources
- ✅ **Azure Subscription** with appropriate permissions
- ✅ **Azure Databricks workspace** (Premium tier recommended)
- ✅ **Azure Machine Learning workspace**
- ✅ **Storage account** (ADLS Gen2)
- ✅ **Network connectivity** between services

#### Python Packages
Install in your Databricks cluster:
```python
%pip install azure-ai-ml azure-identity mlflow scikit-learn pandas numpy
```

#### Authentication
Choose one:
1. **Managed Identity** (Recommended for production)
2. **Service Principal** (Good for automation)
3. **Azure CLI** (Development only)

### Quick Start (5 Minutes)
```python
# 1. Start with quickstart guide
# Open: 01-quickstart/00_Integration_Guide.ipynb

# 2. Test basic connectivity
# Open: 01-quickstart/QUICKSTART_Test_AzureML_Models.ipynb

# 3. Explore based on your needs
# See navigation guide above
```

---

## 📦 Additional Resources

### Scripts
- **[scripts/](./scripts/)** - Reusable Python scripts
  - `train.py` - Sample training script for AzureML
  - `trigger_databricks.py` - Trigger Databricks jobs from AzureML

### Documentation
- **[docs/](./docs/)** - Detailed integration guides
  - `DATABRICKS_AZUREML_INTEGRATION_README.md` - Complete reference

### Infrastructure
- **[infra/](../infra/)** - Bicep templates for Azure infrastructure
- **[terraform/](../terraform/)** - Unity Catalog configuration
- **[docs/](../docs/)** - Deployment and architecture guides

---

## 🎓 Learning Paths

### Path 1: Data Scientist (Feature Engineering Focus)
```
01-quickstart → 02-core-integration → 03-ml-workflows 
→ 05-unity-catalog
```
**Focus:** Working with data, building models, using Unity Catalog features

---

### Path 2: ML Engineer (MLOps Focus)
```
01-quickstart → 02-core-integration → 03-ml-workflows 
→ 04-mlops-orchestration
```
**Focus:** Automation, pipelines, deployment, monitoring

---

### Path 3: Platform Engineer (Infrastructure Focus)
```
02-core-integration → 04-mlops-orchestration → 05-unity-catalog 
→ 06-enterprise-reference
```
**Focus:** Platform setup, governance, security, operations

---

### Path 4: Architect (Design Focus)
```
02-core-integration → 05-unity-catalog → 06-enterprise-reference
```
**Focus:** Architecture patterns, security, compliance, scalability

---

## 🔍 Key Features Demonstrated

### Data & Feature Engineering
- ✅ Spark-based data processing at scale
- ✅ Feature store in Unity Catalog
- ✅ Data quality and validation
- ✅ Medallion architecture (bronze/silver/gold)

### Model Training
- ✅ Distributed training on Azure ML compute
- ✅ Hyperparameter tuning
- ✅ AutoML integration
- ✅ MLflow experiment tracking

### Model Deployment
- ✅ Real-time endpoints (Azure ML + Databricks)
- ✅ Batch scoring at scale
- ✅ Model versioning and registry
- ✅ A/B testing patterns

### MLOps & Automation
- ✅ Pipeline orchestration
- ✅ CI/CD integration
- ✅ Multi-environment deployment
- ✅ Monitoring and alerting

### Governance & Security
- ✅ Unity Catalog data governance
- ✅ Private endpoints and network isolation
- ✅ Managed identity authentication
- ✅ Audit logging and compliance

---

## 🆘 Getting Help

### Troubleshooting
- **Authentication issues:** Check [02-core-integration](./02-core-integration/)
- **Network connectivity:** See [06-enterprise-reference](./06-enterprise-reference/)
- **Deployment errors:** Review [infrastructure docs](../infra/)
- **Unity Catalog:** Reference [05-unity-catalog](./05-unity-catalog/)

### Additional Support
- **Infrastructure deployment:** See [infra/README.md](../infra/README.md)
- **Terraform setup:** See [terraform/README.md](../terraform/README.md)
- **Architecture questions:** See [docs/](../docs/)

---

## 🤝 Contributing

When adding new tutorials:
1. Follow the existing structure and naming conventions
2. Include comprehensive documentation
3. Add prerequisites and time estimates
4. Update this README with links
5. Test all code samples

---

## 📄 License

This project is part of the Azure-Databricks-AzureML repository. See the main repository for license information.

---

## 🎯 Next Steps

1. **New to the integration?** Start with [01-quickstart](./01-quickstart/)
2. **Ready to build?** Jump to [03-ml-workflows](./03-ml-workflows/)
3. **Going to production?** Review [06-enterprise-reference](./06-enterprise-reference/)
4. **Need infrastructure?** Check [deployment guides](../infra/)

**Happy Learning! 🚀**
