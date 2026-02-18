# Sample Scripts for AzureML SDK v2 Integration

This directory contains sample scripts used in the **AzureML_SDK_v2_Complete_Integration.ipynb** notebook.

## 📁 Files

### train.py
A sample training script that demonstrates:
- Command-line argument parsing
- Data loading and preprocessing
- Model training workflow
- Model evaluation
- MLflow experiment tracking
- Model saving and artifact management

**Usage in AzureML:**
```python
from azure.ai.ml import command

job = command(
    code="./src",
    command="python train.py --learning_rate 0.01 --batch_size 32",
    environment="AzureML-sklearn-1.0-ubuntu20.04-py38-cpu@latest",
    compute="my-compute-cluster"
)
```

### trigger_databricks.py
A utility script for triggering Databricks jobs from AzureML pipelines:
- Triggers Databricks job via REST API
- Monitors job execution status
- Handles timeouts and failures
- Returns appropriate exit codes for pipeline orchestration

**Usage in AzureML Pipeline:**
```python
databricks_step = CommandComponent(
    code="./src",
    command="python trigger_databricks.py --job_id <JOB_ID> --token <TOKEN>",
    environment="AzureML-sklearn-1.0-ubuntu20.04-py38-cpu@latest"
)
```

**Environment Variables:**
- `DATABRICKS_INSTANCE`: Databricks workspace URL
- `DATABRICKS_TOKEN`: Access token for authentication

## 🔧 Customization

These are **template scripts** meant to be customized for your specific use case:

1. **train.py**: 
   - Replace placeholder model training with your actual ML code
   - Add your data loading logic
   - Include your feature engineering
   - Customize hyperparameters

2. **trigger_databricks.py**:
   - Adjust timeout values for your job duration
   - Add custom error handling
   - Extend with job parameter passing if needed

## 🔐 Security Best Practices

- **Never hardcode credentials** in these scripts
- Use Azure Key Vault for sensitive values
- Leverage managed identities when possible
- Store tokens in environment variables
- Use service principals for production deployments

## 📚 Related Resources

- [Azure ML SDK v2 Documentation](https://learn.microsoft.com/azure/machine-learning/)
- [Databricks REST API](https://docs.databricks.com/api/workspace/jobs)
- [MLflow Tracking](https://www.mlflow.org/docs/latest/tracking.html)

---

**Note:** These scripts are for demonstration purposes. Modify them according to your production requirements and security policies.
