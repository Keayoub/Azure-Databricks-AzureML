# 🗄️ Unity Catalog Integration

Learn how to integrate Unity Catalog with your ML workflows for data governance, lineage tracking, and secure data access across Databricks and Azure ML.

## 📚 Notebooks

### 1. **06_Unity_Catalog_Integration.ipynb**
**Purpose:** Integrate Unity Catalog for governed ML workflows

**What you'll learn:**
- Unity Catalog architecture and concepts
- Create and manage catalogs, schemas, and tables
- Access Unity Catalog tables from ML workflows
- Register models in Unity Catalog
- Implement fine-grained access controls
- Track data lineage for ML features
- Share data securely across workspaces

**Key concepts:**
- **Catalogs:** Top-level containers for data organization
- **Schemas:** Logical grouping within catalogs (bronze/silver/gold)
- **Tables & Views:** Governed data assets
- **Volumes:** External storage locations
- **Models:** ML model registry with governance

**Use cases:**
- Enterprise data governance for ML
- Multi-team data sharing with access controls
- Auditing and compliance tracking
- Centralized model registry
- Cross-workspace collaboration

**Time to complete:** 60-75 minutes

---

## 🏗️ Unity Catalog Architecture

### Three-Level Namespace
```
<catalog>.<schema>.<table>
    ↓        ↓        ↓
  dev    . bronze . raw_data
  prod   . gold   . ml_features
```

### Example ML Organization
```
dev_lob_team_1              # Development catalog
├── bronze                  # Raw data schema
│   ├── raw_customers
│   └── raw_transactions
├── silver                  # Cleaned data schema
│   ├── clean_customers
│   └── clean_transactions
└── gold                    # Feature schema
    ├── customer_features
    └── transaction_features

prod_lob_team_1            # Production catalog
└── [Same schema structure]
```

---

## 🔒 Access Control Patterns

### Role-Based Access Control (RBAC)
```
Data Engineers:
  - WRITE on bronze, silver schemas
  - READ on gold schemas

Data Scientists:
  - READ on silver, gold schemas
  - EXECUTE on models

ML Engineers:
  - READ on gold schemas
  - WRITE on model registry
  - DEPLOY models
```

### Implementing Access Controls
```sql
-- Grant read access to data scientists
GRANT SELECT ON SCHEMA prod_lob_team_1.gold 
TO `data-scientists@company.com`;

-- Grant model deployment to ML engineers
GRANT EXECUTE ON FUNCTION prod_lob_team_1.models.predict 
TO `ml-engineers@company.com`;
```

---

## 📊 Data Lineage for ML

### Tracking Feature Lineage
```
Source Data → Transformations → Features → Model → Predictions
     ↓              ↓              ↓         ↓         ↓
  Unity         Unity          Unity     Unity    Unity
  Catalog       Catalog        Catalog   Catalog  Catalog
  (bronze)      (silver)       (gold)   (models) (results)
```

### Benefits
- **Reproducibility:** Trace model inputs back to source
- **Compliance:** Audit data usage for regulations
- **Impact Analysis:** Understand downstream effects of changes
- **Debugging:** Identify data quality issues

---

## 🔄 Integration with ML Workflows

### Pattern 1: Feature Store
```python
# Read features from Unity Catalog
features = spark.table("prod_lob_team_1.gold.customer_features")

# Train model
model = train_model(features)

# Register in Unity Catalog model registry
mlflow.register_model(
    model_uri=f"runs:/{run.info.run_id}/model",
    name="prod_lob_team_1.models.customer_churn"
)
```

### Pattern 2: Batch Scoring with Governance
```python
# Read production features (governed)
input_data = spark.table("prod_lob_team_1.gold.scoring_features")

# Load model from Unity Catalog
model = mlflow.pyfunc.load_model("models:/prod_lob_team_1.models.customer_churn/Production")

# Score and write back to governed table
predictions = model.predict(input_data)
predictions.write.saveAsTable("prod_lob_team_1.gold.predictions")
```

### Pattern 3: Cross-Workspace Collaboration
```python
# Grant access to another workspace
GRANT SELECT ON TABLE prod_lob_team_1.gold.customer_features 
TO EXTERNAL `workspace_id_123`;

# Access from different workspace
features = spark.table("prod_lob_team_1.gold.customer_features")
```

---

## 🎯 Best Practices

### 1. Catalog Organization
- ✅ Use environment-based catalogs: `dev_`, `qa_`, `prod_`
- ✅ Implement medallion architecture: bronze → silver → gold
- ✅ Separate raw data, features, and models
- ✅ Use consistent naming conventions

### 2. Access Control
- ✅ Principle of least privilege
- ✅ Use groups instead of individual users
- ✅ Regular access audits
- ✅ Separate read/write permissions

### 3. Model Governance
- ✅ Register all production models in Unity Catalog
- ✅ Use model stages (Development, Staging, Production)
- ✅ Document model metadata and requirements
- ✅ Track model lineage back to training data

### 4. Data Quality
- ✅ Implement data validation in bronze → silver
- ✅ Use expectations and constraints
- ✅ Monitor data drift
- ✅ Maintain data quality metrics in Unity Catalog

---

## 🔗 Unity Catalog + Azure ML Integration

### Scenario 1: Training in AzureML with Unity Catalog Data
```python
# In Databricks: Export features from Unity Catalog
features = spark.table("prod_lob_team_1.gold.ml_features")
features.write.parquet("abfss://data@storage.dfs.core.windows.net/features/")

# In AzureML: Access via datastore
from azure.ai.ml import MLClient
ml_client = MLClient(...)
dataset = ml_client.data.get("unity-catalog-features", version="1")
```

### Scenario 2: Model Deployment with Unity Catalog
```python
# Register model in Unity Catalog from AzureML training
mlflow.set_registry_uri("databricks-uc")
mlflow.register_model(
    model_uri="runs:/xyz/model",
    name="prod_lob_team_1.models.fraud_detection"
)
```

---

## 🗺️ Unity Catalog + Infrastructure

This project's infrastructure (deployed via Bicep + Terraform) includes:

### Terraform-Managed Resources
- ✅ Unity Catalog metastore (Canada East)
- ✅ Catalogs: `dev_lob_team_1`, `qa_lob_team_1`, `prod_lob_team_1`
- ✅ Schemas: bronze, silver, gold in each catalog
- ✅ External locations with managed identity
- ✅ Storage credentials (no shared access keys)

### Integration Points
- **Storage:** ADLS Gen2 with `unitycatalog` container
- **Authentication:** Access Connector with managed identity
- **Security:** Private endpoints, no public access

**See:** [Infrastructure docs](../../infra/) and [Terraform modules](../../terraform/)

---

## 📋 Prerequisites

### Required Setup
- ✅ Databricks workspace with Unity Catalog enabled
- ✅ Account-level admin access (for initial setup)
- ✅ Unity Catalog metastore assigned to workspace
- ✅ ADLS Gen2 storage account for external tables
- ✅ Appropriate RBAC roles on storage

### Python Packages
```python
# Unity Catalog is built-in to Databricks Runtime 11.3+
# No additional packages needed for basic usage

# For advanced features:
%pip install databricks-sdk mlflow
```

---

## 🎓 Learning Path

### Beginner
1. Read Unity Catalog concepts (first half of notebook)
2. Create basic catalog and schema
3. Create governed tables
4. Grant simple permissions

### Intermediate
1. Implement medallion architecture
2. Set up model registry in Unity Catalog
3. Integrate with ML workflows
4. Configure access controls

### Advanced
1. Multi-workspace sharing
2. External locations and volumes
3. Custom grants and row-level security
4. Integrate with [MLOps orchestration](../04-mlops-orchestration/)

---

## 🔍 Common Use Cases

### Use Case 1: Centralized Feature Store
**Goal:** Single source of truth for ML features
**Implementation:** `gold` schema in Unity Catalog with versioned feature tables

### Use Case 2: Multi-Environment ML
**Goal:** Promote features from dev → qa → prod
**Implementation:** Separate catalogs per environment with controlled promotion

### Use Case 3: Secure Model Deployment
**Goal:** Only authorized users can deploy production models
**Implementation:** RBAC on model registry with approval workflows

### Use Case 4: Cross-Team Data Sharing
**Goal:** Enable collaboration without copying data
**Implementation:** Grant SELECT on specific schemas to other teams

---

## 📚 Additional Resources

- [Unity Catalog Documentation](https://docs.databricks.com/data-governance/unity-catalog/)
- [Unity Catalog Best Practices](https://docs.databricks.com/data-governance/unity-catalog/best-practices.html)
- [Unity Catalog with MLflow](https://docs.databricks.com/machine-learning/manage-model-lifecycle/index.html)
- [Unity Catalog + Azure ML](https://learn.microsoft.com/azure/databricks/integrations/azure-ml)

---

## 🛠️ Infrastructure Integration

Unity Catalog is deployed via Terraform in this project:
- **Module:** `terraform/modules/adb-uc-metastore/`
- **Configuration:** `terraform/environments/main.tf`
- **Reference:** [Terraform README](../../terraform/README.md)

---

[← Back to MLOps](../04-mlops-orchestration/) | [Next: Enterprise Reference →](../06-enterprise-reference/)
