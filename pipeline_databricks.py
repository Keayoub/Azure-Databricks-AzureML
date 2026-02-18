"""
AzureML Pipeline with Databricks Job Integration

This script creates and submits an Azure Machine Learning pipeline that triggers
a Databricks job as part of the workflow.

Prerequisites:
- Azure Machine Learning workspace
- Azure Databricks workspace with an existing job
- Appropriate permissions to access both services
- Databricks access token (recommended: store in Azure Key Vault)

Required Configuration:
Replace the placeholders marked with <...> before running:
- <SUBSCRIPTION_ID>: Your Azure subscription ID
- <RESOURCE_GROUP>: Resource group containing your AzureML workspace
- <AML_WORKSPACE>: Name of your AzureML workspace
- <COMPUTE_CLUSTER_NAME>: AzureML compute cluster name
- <DATABRICKSWORKSPACEURL>: Databricks workspace URL (e.g., https://adb-123456.azuredatabricks.net)
- <DATABRICKSJOBID>: Databricks job ID to trigger
- <DATABRICKS_TOKEN>: Databricks access token (DO NOT hardcode - use Key Vault!)

Usage:
    python pipeline_databricks.py

Security Note:
Never hardcode sensitive values like Databricks tokens in source code.
Use Azure Key Vault secrets or environment variables instead.
"""

from azure.ai.ml import MLClient, command, Input
from azure.identity import DefaultAzureCredential
from azure.ai.ml import dsl
from azure.ai.ml.entities import PipelineJob, Environment
import os


# ============================================================================
# Configuration Section - Replace all placeholders
# ============================================================================

# Azure ML Workspace Configuration
SUBSCRIPTION_ID = "<SUBSCRIPTION_ID>"  # TODO: Replace with your subscription ID
RESOURCE_GROUP = "<RESOURCE_GROUP>"    # TODO: Replace with your resource group
AML_WORKSPACE = "<AML_WORKSPACE>"      # TODO: Replace with your workspace name

# Compute Configuration
COMPUTE_CLUSTER_NAME = "<COMPUTE_CLUSTER_NAME>"  # TODO: Replace with your compute cluster

# Databricks Configuration
DATABRICKS_WORKSPACE_URL = "<DATABRICKSWORKSPACEURL>"  # TODO: e.g., https://adb-123456.azuredatabricks.net
DATABRICKS_JOB_ID = "<DATABRICKSJOBID>"                # TODO: e.g., 123456
DATABRICKS_TOKEN = "<DATABRICKS_TOKEN>"                # TODO: Replace or use Key Vault!

# Pipeline Configuration
PIPELINE_NAME = "databricks-integration-pipeline"
PIPELINE_DESCRIPTION = "AzureML pipeline that triggers a Databricks job as a step"
EXPERIMENT_NAME = "databricks-pipeline-integration"


# ============================================================================
# Main Script
# ============================================================================

def authenticate_azureml() -> MLClient:
    """
    Authenticate to Azure Machine Learning using DefaultAzureCredential.
    
    DefaultAzureCredential attempts authentication in the following order:
    1. Environment variables (AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_CLIENT_SECRET)
    2. Managed Identity (if running in Azure)
    3. Azure CLI credentials
    4. Visual Studio Code credentials
    5. Azure PowerShell credentials
    
    Returns:
        MLClient: Authenticated Azure ML client
    """
    print("Authenticating to Azure Machine Learning...")
    
    credential = DefaultAzureCredential()
    
    ml_client = MLClient(
        credential=credential,
        subscription_id=SUBSCRIPTION_ID,
        resource_group_name=RESOURCE_GROUP,
        workspace_name=AML_WORKSPACE
    )
    
    print(f"✓ Connected to AzureML workspace: {AML_WORKSPACE}")
    print(f"  Resource Group: {RESOURCE_GROUP}")
    print(f"  Subscription: {SUBSCRIPTION_ID}")
    
    return ml_client


def create_databricks_trigger_script(output_dir: str = "./src"):
    """
    Create a Python script that triggers a Databricks job via REST API.
    
    This script will be executed as part of the AzureML pipeline to trigger
    the Databricks job.
    
    Args:
        output_dir: Directory to save the trigger script
    """
    os.makedirs(output_dir, exist_ok=True)
    
    script_content = '''"""
Script to trigger a Databricks job from AzureML pipeline.
"""
import requests
import json
import time
import argparse
import sys

def trigger_databricks_job(workspace_url, job_id, token):
    """
    Trigger a Databricks job and wait for completion.
    
    Args:
        workspace_url: Databricks workspace URL
        job_id: Databricks job ID to trigger
        token: Databricks access token
    """
    # Remove trailing slash from workspace URL
    workspace_url = workspace_url.rstrip('/')
    
    # API endpoint for triggering a job
    api_endpoint = f"{workspace_url}/api/2.1/jobs/run-now"
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    payload = {
        "job_id": int(job_id)
    }
    
    print(f"Triggering Databricks job {job_id}...")
    print(f"Workspace: {workspace_url}")
    
    try:
        # Trigger the job
        response = requests.post(api_endpoint, headers=headers, json=payload)
        response.raise_for_status()
        
        run_data = response.json()
        run_id = run_data.get("run_id")
        
        print(f"✓ Job triggered successfully!")
        print(f"  Run ID: {run_id}")
        
        # Poll for job completion
        status_endpoint = f"{workspace_url}/api/2.1/jobs/runs/get"
        
        print("\\nWaiting for job to complete...")
        while True:
            status_response = requests.get(
                status_endpoint,
                headers=headers,
                params={"run_id": run_id}
            )
            status_response.raise_for_status()
            
            run_info = status_response.json()
            state = run_info.get("state", {})
            life_cycle_state = state.get("life_cycle_state")
            
            print(f"  Status: {life_cycle_state}")
            
            if life_cycle_state in ["TERMINATED", "SKIPPED", "INTERNAL_ERROR"]:
                result_state = state.get("result_state")
                print(f"\\n✓ Job completed with state: {result_state}")
                
                if result_state == "SUCCESS":
                    print("Job executed successfully!")
                    return 0
                else:
                    state_message = state.get("state_message", "No message")
                    print(f"Job failed: {state_message}")
                    return 1
            
            time.sleep(30)  # Poll every 30 seconds
            
    except requests.exceptions.RequestException as e:
        print(f"✗ Error triggering Databricks job: {e}")
        if hasattr(e.response, 'text'):
            print(f"Response: {e.response.text}")
        return 1

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Trigger a Databricks job")
    parser.add_argument("--workspace-url", required=True, help="Databricks workspace URL")
    parser.add_argument("--job-id", required=True, help="Databricks job ID")
    parser.add_argument("--token", required=True, help="Databricks access token")
    
    args = parser.parse_args()
    
    exit_code = trigger_databricks_job(
        args.workspace_url,
        args.job_id,
        args.token
    )
    
    sys.exit(exit_code)
'''
    
    script_path = os.path.join(output_dir, "trigger_databricks.py")
    with open(script_path, 'w') as f:
        f.write(script_content)
    
    print(f"✓ Created Databricks trigger script: {script_path}")


def define_databricks_step():
    """
    Define a Databricks job trigger step for the AzureML pipeline.
    
    This creates a command component that executes a Python script to trigger
    a Databricks job via REST API.
    
    Returns:
        Command component configured to trigger Databricks job
    """
    print("\nDefining Databricks pipeline step...")
    
    # Define the command component
    databricks_component = command(
        name="trigger-databricks-job",
        display_name="Trigger Databricks Job",
        description="Triggers a Databricks job using REST API and waits for completion",
        
        # Source code directory containing trigger_databricks.py
        code="./src",
        
        # Command to execute
        command="""python trigger_databricks.py \
            --workspace-url ${{inputs.workspace_url}} \
            --job-id ${{inputs.job_id}} \
            --token ${{inputs.token}}""",
        
        # Environment with required dependencies
        environment="AzureML-sklearn-1.0-ubuntu20.04-py38-cpu@latest",
        
        # Input parameters
        inputs={
            "workspace_url": Input(type="string", default=DATABRICKS_WORKSPACE_URL),
            "job_id": Input(type="string", default=DATABRICKS_JOB_ID),
            "token": Input(type="string", default=DATABRICKS_TOKEN)
        },
        
        # Compute target
        compute=COMPUTE_CLUSTER_NAME
    )
    
    print("✓ Databricks step defined")
    print(f"  Workspace URL: {DATABRICKS_WORKSPACE_URL}")
    print(f"  Job ID: {DATABRICKS_JOB_ID}")
    print(f"  Compute: {COMPUTE_CLUSTER_NAME}")
    
    return databricks_component


def build_pipeline(databricks_component):
    """
    Build the AzureML pipeline with Databricks integration.
    
    The pipeline includes:
    - A Databricks job trigger step
    - Configurable inputs for Databricks connection details
    
    Args:
        databricks_component: The Databricks trigger component
        
    Returns:
        PipelineJob: Configured pipeline ready for submission
    """
    print("\nBuilding pipeline...")
    
    @dsl.pipeline(
        name=PIPELINE_NAME,
        description=PIPELINE_DESCRIPTION,
        compute=COMPUTE_CLUSTER_NAME
    )
    def databricks_integration_pipeline():
        """
        AzureML pipeline that integrates with Databricks.
        
        This pipeline triggers a Databricks job and waits for its completion.
        """
        # Add the Databricks trigger step
        databricks_step = databricks_component()
        
        # Configure step properties
        databricks_step.compute = COMPUTE_CLUSTER_NAME
        
        return {}
    
    # Create pipeline instance
    pipeline_job = databricks_integration_pipeline()
    
    # Set pipeline-level settings
    pipeline_job.settings.default_compute = COMPUTE_CLUSTER_NAME
    
    print("✓ Pipeline built successfully")
    print(f"  Pipeline Name: {PIPELINE_NAME}")
    print(f"  Description: {PIPELINE_DESCRIPTION}")
    
    return pipeline_job


def submit_pipeline(ml_client: MLClient, pipeline_job: PipelineJob):
    """
    Submit the pipeline to Azure Machine Learning.
    
    Args:
        ml_client: Authenticated MLClient instance
        pipeline_job: Pipeline to submit
        
    Returns:
        Submitted pipeline job object
    """
    print("\nSubmitting pipeline to AzureML...")
    
    try:
        # Submit the pipeline
        returned_job = ml_client.jobs.create_or_update(
            pipeline_job,
            experiment_name=EXPERIMENT_NAME
        )
        
        print("✓ Pipeline submitted successfully!")
        print(f"  Pipeline Name: {returned_job.name}")
        print(f"  Pipeline ID: {returned_job.id}")
        print(f"  Status: {returned_job.status}")
        print(f"  Experiment: {EXPERIMENT_NAME}")
        print(f"\n  View pipeline in Azure Portal:")
        print(f"  {returned_job.studio_url}")
        
        return returned_job
        
    except Exception as e:
        print(f"✗ Error submitting pipeline: {e}")
        raise


def main():
    """
    Main execution function.
    
    Orchestrates the complete workflow:
    1. Authenticate to AzureML
    2. Create helper scripts
    3. Define pipeline components
    4. Build pipeline
    5. Submit pipeline
    """
    print("=" * 80)
    print("AZUREML PIPELINE WITH DATABRICKS INTEGRATION")
    print("=" * 80)
    
    try:
        # Step 1: Authenticate
        ml_client = authenticate_azureml()
        
        # Step 2: Create Databricks trigger script
        print("\nCreating Databricks trigger script...")
        create_databricks_trigger_script()
        
        # Step 3: Define Databricks step
        databricks_component = define_databricks_step()
        
        # Step 4: Build pipeline
        pipeline_job = build_pipeline(databricks_component)
        
        # Step 5: Submit pipeline
        returned_job = submit_pipeline(ml_client, pipeline_job)
        
        print("\n" + "=" * 80)
        print("✓ PIPELINE DEPLOYMENT COMPLETE")
        print("=" * 80)
        print(f"\nPipeline Details:")
        print(f"  Name: {returned_job.name}")
        print(f"  Experiment: {EXPERIMENT_NAME}")
        print(f"  Status: {returned_job.status}")
        print(f"\nMonitor your pipeline at:")
        print(f"  {returned_job.studio_url}")
        print("\n" + "=" * 80)
        
        return 0
        
    except Exception as e:
        print("\n" + "=" * 80)
        print("✗ PIPELINE DEPLOYMENT FAILED")
        print("=" * 80)
        print(f"Error: {e}")
        return 1


if __name__ == "__main__":
    exit(main())
