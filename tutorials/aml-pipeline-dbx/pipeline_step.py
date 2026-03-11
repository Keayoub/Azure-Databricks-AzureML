"""
pipeline_step.py
----------------
AzureML pipeline step entry point.
Reads input from AzureML pipeline parameters, invokes Databricks, writes output.

Usage in AzureML pipeline:
    command(
        code="./src",
        command="python pipeline_step.py --input-text ${{inputs.text}}",
        environment="...",
        identity=ManagedIdentityConfiguration(client_id="<uami-client-id>"),
    )
"""

import argparse
import json
import logging
import os
import sys
from typing import Optional

from databricks_client import DatabricksServingClient

# Structured logging for AzureML job logs
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
    stream=sys.stdout,
)
logger = logging.getLogger("pipeline_step")


def build_payload(input_text: Optional[str] = None) -> dict:
    """
    Build the Databricks scoring payload.
    Priority: CLI arg > DATABRICKS_SAMPLE_INPUT_JSON env var > default.
    """
    if input_text:
        return {
            "dataframe_split": {
                "columns": ["text"],
                "data": [[input_text]],
            }
        }

    env_payload = os.getenv("DATABRICKS_SAMPLE_INPUT_JSON")
    if env_payload:
        return json.loads(env_payload)

    # Default test payload
    return {
        "dataframe_split": {
            "columns": ["text"],
            "data": [["hello from azureml pipeline"]],
        }
    }


def parse_args():
    parser = argparse.ArgumentParser(description="AzureML -> Databricks pipeline step")
    parser.add_argument(
        "--input-text",
        type=str,
        default=None,
        help="Text input to score against the Databricks endpoint",
    )
    parser.add_argument(
        "--output-path",
        type=str,
        default=None,
        help="Optional path to write JSON response output",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    logger.info("Initializing Databricks client from environment")
    client = DatabricksServingClient.from_environment()

    payload = build_payload(args.input_text)
    logger.info("Payload built: %s", json.dumps(payload))

    result = client.invoke(payload)
    logger.info("Result: %s", json.dumps(result, indent=2))

    if args.output_path:
        output_dir = os.path.dirname(args.output_path)
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)
        with open(args.output_path, "w") as f:
            json.dump(result, f, indent=2)
        logger.info("Output written to %s", args.output_path)

    return result


if __name__ == "__main__":
    main()
