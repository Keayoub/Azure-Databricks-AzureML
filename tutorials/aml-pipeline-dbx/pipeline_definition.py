"""
pipeline_definition.py
-----------------------
AzureML SDK v2 pipeline definition.
Wires the UAMI identity to the compute job.

Run with:
    python pipeline_definition.py
"""

import logging
import os

from azure.ai.ml import MLClient, command, Input
from azure.ai.ml.entities import ManagedIdentityConfiguration
from azure.identity import DefaultAzureCredential

logger = logging.getLogger(__name__)


def get_ml_client() -> MLClient:
    """
    MLClient uses DefaultAzureCredential here because this runs
    locally or in a CI/CD context (not inside AzureML compute).
    The IMDS proxy issue only affects code running inside AzureML jobs.
    """
    return MLClient(
        credential=DefaultAzureCredential(),
        subscription_id=os.environ["AZURE_SUBSCRIPTION_ID"],
        resource_group_name=os.environ["AZURE_RESOURCE_GROUP"],
        workspace_name=os.environ["AZUREML_WORKSPACE_NAME"],
    )


def build_pipeline_job(uami_client_id: str):
    """
    Build and return the AzureML command job.

    The UAMI client_id is passed as the job identity — this is what
    makes ManagedIdentityCredential(client_id=...) work inside the job.
    """
    return command(
        display_name="databricks-serving-invoke",
        description="Invoke a Databricks Model Serving endpoint from AzureML",
        code="./",  # Directory containing pipeline_step.py, auth.py, databricks_client.py
        command=(
            "python pipeline_step.py "
            "--input-text '${{inputs.input_text}}' "
            "--output-path '${{outputs.result_path}}'"
        ),
        inputs={
            "input_text": Input(type="string", default="hello from azureml"),
        },
        environment_variables={
            # Auth — UAMI path (no secret needed)
            "AZURE_CLIENT_ID": uami_client_id,

            # Databricks config
            "DATABRICKS_HOST": os.environ["DATABRICKS_HOST"],
            "DATABRICKS_ENDPOINT_NAME": os.environ["DATABRICKS_ENDPOINT_NAME"],
        },
        # Attach UAMI as the job identity
        identity=ManagedIdentityConfiguration(client_id=uami_client_id),
        compute=os.environ.get("AZUREML_COMPUTE_NAME", "cpu-cluster"),
    )


def main():
    logging.basicConfig(level=logging.INFO)

    uami_client_id = os.environ["AZURE_CLIENT_ID"]  # UAMI client ID

    ml_client = get_ml_client()
    job = build_pipeline_job(uami_client_id)

    submitted = ml_client.jobs.create_or_update(job)
    logger.info("Job submitted: %s", submitted.name)
    logger.info("Studio URL: %s", submitted.studio_url)


if __name__ == "__main__":
    main()
