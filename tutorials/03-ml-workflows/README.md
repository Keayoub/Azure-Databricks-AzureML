# 🤖 ML Workflows

End-to-end machine learning workflows demonstrating the complete lifecycle from feature engineering to model deployment and inference.

## 📚 Notebooks

### 1. **01_Feature_Engineering_Preparation.ipynb**
**Purpose:** Prepare and engineer features in Databricks for ML model training

**What you'll learn:**
- Load raw data from Azure Storage (ADLS Gen2)
- Data cleaning and transformation with Spark
- Feature engineering and derived features
- Unity Catalog feature store creation
- Export data for AzureML (CSV/Parquet)
- Data quality validation and profiling

**Use cases:**
- Large-scale data preparation with Spark
- Feature engineering for distributed datasets
- Creating reusable feature pipelines
- Unity Catalog integration for data governance

**Outputs:**
- Cleaned and transformed datasets
- Feature definitions in Unity Catalog
- Exported datasets ready for training

**Time to complete:** 45-60 minutes

---

### 2. **02_Model_Training_Pipeline.ipynb**
**Purpose:** Build and execute training pipelines across Databricks and AzureML

**What you'll learn:**
- Submit training jobs from Databricks to AzureML
- Configure compute resources and environments
- Hyperparameter tuning with AzureML
- Distributed training patterns
- MLflow experiment tracking
- Model registration and versioning

**Use cases:**
- Training models on AzureML managed compute
- Hyperparameter optimization at scale
- Multi-model training pipelines
- Experiment tracking and comparison

**Prerequisites:**
- Completed feature engineering (Notebook 01)
- AzureML compute cluster configured

**Time to complete:** 60-90 minutes

---

### 3. **03_Batch_Prediction_Scoring.ipynb**
**Purpose:** Execute large-scale batch scoring using trained models

**What you'll learn:**
- Load registered models from AzureML
- Batch inference on Databricks clusters
- Parallel scoring with Spark UDFs
- Write predictions to Unity Catalog
- Performance optimization for batch scoring
- Error handling for production workloads

**Use cases:**
- Daily/weekly batch scoring jobs
- Scoring millions of records efficiently
- Writing results to data lakehouse
- Production batch inference pipelines

**Prerequisites:**
- Trained and registered model (Notebook 02)
- Input datasets for scoring

**Time to complete:** 45-60 minutes

---

### 4. **05_Real_Time_Inference.ipynb**
**Purpose:** Deploy and consume real-time model endpoints

**What you'll learn:**
- Deploy models to AzureML online endpoints
- Deploy models to Databricks model serving
- Call endpoints for real-time predictions
- Handle authentication and authorization
- Load testing and performance tuning
- Monitoring and logging

**Use cases:**
- Low-latency prediction APIs
- Interactive applications requiring real-time scoring
- A/B testing multiple model versions
- Blue/green deployment strategies

**Prerequisites:**
- Trained model (Notebook 02)
- Understanding of REST APIs

**Time to complete:** 60-75 minutes

---

### 5. **07_Testing_AzureML_Models.ipynb**
**Purpose:** Comprehensive testing and validation of deployed models

**What you'll learn:**
- Model performance testing
- Input validation and error handling
- Load testing and stress testing
- Model drift detection
- Integration testing patterns
- Regression testing for model updates

**Use cases:**
- Validating model behavior before production
- Continuous testing in CI/CD pipelines
- Model monitoring and quality assurance
- Detecting performance degradation

**Time to complete:** 45-60 minutes

---

## 🔄 Complete ML Workflow

Follow this sequence for a complete end-to-end ML workflow:

```
1. Feature Engineering (01_Feature_Engineering_Preparation.ipynb)
   ↓ [Cleaned datasets, feature definitions]
   
2. Model Training (02_Model_Training_Pipeline.ipynb)
   ↓ [Trained models, metrics, artifacts]
   
3. Model Testing (07_Testing_AzureML_Models.ipynb)
   ↓ [Validation results, quality metrics]
   
4. Choose deployment path:
   
   Path A: Batch Scoring
   → 03_Batch_Prediction_Scoring.ipynb
   [Schedule daily/weekly scoring jobs]
   
   Path B: Real-time Inference  
   → 05_Real_Time_Inference.ipynb
   [Deploy API endpoint for on-demand predictions]
```

---

## 🎯 Workflow Patterns

### Pattern 1: Databricks Feature Engineering → AzureML Training
**Best for:** Teams with large-scale data in Databricks, need managed training compute
```
Databricks Spark → Feature Store → AzureML Training → Model Registry
```

### Pattern 2: Hybrid Training and Serving
**Best for:** Different models on different platforms based on requirements
```
Databricks: Feature prep + Batch scoring
AzureML: Training + Real-time serving
```

### Pattern 3: Full Databricks with AzureML Orchestration
**Best for:** Databricks-first teams, using AzureML for MLOps capabilities
```
All compute on Databricks, orchestrated via AzureML pipelines
```

---

## 📊 Data Flow

### Unity Catalog Integration
```
Raw Data (Bronze) → Clean Data (Silver) → Features (Gold)
         ↓                    ↓                  ↓
    Unity Catalog      Unity Catalog      Feature Store
         ↓                    ↓                  ↓
         └─────────────→ AzureML Training ←─────┘
                             ↓
                    Registered Model
                             ↓
               ┌─────────────┴─────────────┐
               ↓                           ↓
         Batch Endpoint              Online Endpoint
               ↓                           ↓
      Unity Catalog Tables           REST API
```

---

## 📋 Prerequisites

### Required Resources
- ✅ Databricks workspace with Unity Catalog enabled
- ✅ Azure Machine Learning workspace
- ✅ ADLS Gen2 storage account
- ✅ Compute clusters configured in both platforms

### Python Packages
```python
# Install in Databricks cluster
%pip install azure-ai-ml azure-identity mlflow scikit-learn pandas numpy
```

### Data Requirements
- Sample datasets or your own training data
- Access to Unity Catalog for feature storage
- Write permissions to storage accounts

---

## 🎓 Learning Path

### Beginner Path
1. Start with **01_Feature_Engineering_Preparation**
2. Run **02_Model_Training_Pipeline** with provided sample data
3. Test with **07_Testing_AzureML_Models**

### Intermediate Path
1. Complete all notebooks in sequence
2. Modify for your own datasets
3. Customize feature engineering logic

### Advanced Path
1. Integrate with [MLOps Orchestration](../04-mlops-orchestration/)
2. Add [Unity Catalog governance](../05-unity-catalog/)
3. Implement production patterns from [Enterprise Reference](../06-enterprise-reference/)

---

## 🔍 Common Scenarios

### Scenario 1: Daily Batch Predictions
Use: `01 → 02 → 03` then schedule notebook 03 daily

### Scenario 2: API-First Application
Use: `01 → 02 → 05` then integrate endpoint into your app

### Scenario 3: Model Comparison
Use: `02` (train multiple models) → `07` (compare performance) → Choose best

### Scenario 4: Incremental Learning
Use: `01` (new data) → `02` (retrain) → `07` (validate) → `03 or 05` (deploy)

---

## 📚 Additional Resources

- [Databricks Feature Store](https://docs.databricks.com/machine-learning/feature-store/)
- [AzureML Pipelines](https://learn.microsoft.com/azure/machine-learning/concept-ml-pipelines)
- [Unity Catalog ML](https://docs.databricks.com/data-governance/unity-catalog/)
- [MLflow Documentation](https://mlflow.org/docs/latest/index.html)

---

[← Back to Core Integration](../02-core-integration/) | [Next: MLOps Orchestration →](../04-mlops-orchestration/)
