"""
databricks_client.py
--------------------
Thin HTTP client for invoking Databricks Model Serving endpoints.
Handles retries, structured error handling, and token refresh.
"""

import json
import logging
import os
from typing import Any, Dict, Optional

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from auth import AuthConfig, DatabricksTokenProvider

logger = logging.getLogger(__name__)

# Retry on transient server errors and network issues
_RETRY_STRATEGY = Retry(
    total=3,
    backoff_factor=1,             # 1s, 2s, 4s
    status_forcelist=[429, 502, 503, 504],
    allowed_methods=["POST"],
    raise_on_status=False,
)


class DatabricksServingClient:
    """
    Client for invoking a Databricks Model Serving endpoint.

    Usage:
        client = DatabricksServingClient.from_environment()
        result = client.invoke({"dataframe_split": {"columns": ["text"], "data": [["hello"]]}})
    """

    def __init__(
        self,
        host: str,
        endpoint_name: str,
        token_provider: DatabricksTokenProvider,
        timeout: int = 60,
    ):
        self._host = host.rstrip("/")
        self._endpoint_name = endpoint_name
        self._token_provider = token_provider
        self._timeout = timeout
        self._session = self._build_session()

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

        auth_config = AuthConfig.from_environment()
        token_provider = DatabricksTokenProvider(auth_config)

        return cls(
            host=host,
            endpoint_name=endpoint_name,
            token_provider=token_provider,
        )

    @staticmethod
    def _build_session() -> requests.Session:
        session = requests.Session()
        adapter = HTTPAdapter(max_retries=_RETRY_STRATEGY)
        session.mount("https://", adapter)
        return session

    @property
    def _endpoint_url(self) -> str:
        return f"{self._host}/serving-endpoints/{self._endpoint_name}/invocations"

    def _build_headers(self) -> Dict[str, str]:
        return {
            "Authorization": f"Bearer {self._token_provider.get_token()}",
            "Content-Type": "application/json",
        }

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
            requests.HTTPError: On 4xx/5xx responses after retries.
            requests.Timeout:   If the request exceeds the timeout.
        """
        logger.info(
            "Invoking Databricks endpoint: %s/%s",
            self._host, self._endpoint_name,
        )
        logger.debug("Payload: %s", json.dumps(payload))

        try:
            response = self._session.post(
                self._endpoint_url,
                headers=self._build_headers(),
                json=payload,
                timeout=self._timeout,
            )
        except requests.Timeout:
            logger.error("Request timed out after %ss", self._timeout)
            raise
        except requests.ConnectionError as e:
            logger.error("Connection error reaching Databricks: %s", e)
            raise

        if not response.ok:
            logger.error(
                "Databricks endpoint returned %s: %s",
                response.status_code, response.text,
            )
            response.raise_for_status()

        result = response.json()
        logger.info("Endpoint invocation succeeded (status=%s)", response.status_code)
        logger.debug("Response: %s", json.dumps(result))
        return result
