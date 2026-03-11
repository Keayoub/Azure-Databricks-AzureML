"""
databricks_client.py
--------------------
Databricks SDK client for invoking Model Serving endpoints.
Uses WorkspaceClient for auth, retries, and connection management.
"""

import json
import logging
import os
from typing import Any, Dict

from databricks.sdk import WorkspaceClient

from auth import build_workspace_client

logger = logging.getLogger(__name__)


class DatabricksServingClient:
    """
    Client for invoking a Databricks Model Serving endpoint via the Databricks SDK.

    Usage:
        client = DatabricksServingClient.from_environment()
        result = client.invoke({"dataframe_split": {"columns": ["text"], "data": [["hello"]]}})
    """

    def __init__(self, workspace_client: WorkspaceClient, endpoint_name: str):
        self._client = workspace_client
        self._endpoint_name = endpoint_name

    @classmethod
    def from_environment(cls) -> "DatabricksServingClient":
        """
        Factory method — reads all config from environment variables.

        Required env vars:
            DATABRICKS_HOST             e.g. https://adb-xxxx.azuredatabricks.net
            DATABRICKS_ENDPOINT_NAME    e.g. my-model-endpoint

        Auth env vars (see auth.py):
            AZURE_CLIENT_ID             UAMI client ID (production)
            AZURE_TENANT_ID  \
            AZURE_CLIENT_ID   >         SPN credentials (dev/CI)
            AZURE_CLIENT_SECRET /
        """
        host = os.environ.get("DATABRICKS_HOST")
        endpoint_name = os.environ.get("DATABRICKS_ENDPOINT_NAME")

        missing = [k for k, v in {
            "DATABRICKS_HOST": host,
            "DATABRICKS_ENDPOINT_NAME": endpoint_name,
        }.items() if not v]

        if missing:
            raise EnvironmentError(
                f"Missing required environment variables: {', '.join(missing)}"
            )

        assert host is not None
        assert endpoint_name is not None
        workspace_client = build_workspace_client(host)
        return cls(workspace_client=workspace_client, endpoint_name=endpoint_name)

    def invoke(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """
        Invoke the model serving endpoint with the given payload.

        Args:
            payload: Databricks-compatible scoring payload.
                     e.g. {"dataframe_split": {"columns": [...], "data": [...]}}
                     or   {"inputs": [...]}

        Returns:
            Parsed JSON response from the endpoint.

        Raises:
            DatabricksError: On 4xx/5xx responses (raised by the SDK).
        """
        logger.info("Invoking Databricks endpoint: %s", self._endpoint_name)
        logger.debug("Payload: %s", json.dumps(payload))

        response = self._client.api_client.do(
            "POST",
            f"/serving-endpoints/{self._endpoint_name}/invocations",
            body=payload,
        )

        logger.info("Endpoint invocation succeeded")
        logger.debug("Response: %s", json.dumps(response))
        return response
