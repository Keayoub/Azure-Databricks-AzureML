"""
auth.py
-------
Authentication module for AzureML -> Databricks connectivity.
Builds a Databricks SDK WorkspaceClient using UAMI (production),
SPN (dev/CI), or SAMI (fallback).
No secrets in code. All config via environment variables.
"""

import logging
import os

from databricks.sdk import WorkspaceClient

logger = logging.getLogger(__name__)


def build_workspace_client(host: str) -> WorkspaceClient:
    """
    Build a Databricks WorkspaceClient using the appropriate credential.
    Priority: UAMI > SPN > SAMI

    Environment variables:
        AZURE_CLIENT_ID       - UAMI client ID (triggers UAMI mode)
        AZURE_TENANT_ID       - Required only for SPN mode
        AZURE_CLIENT_SECRET   - Required only for SPN mode
    """
    client_id = os.getenv("AZURE_CLIENT_ID")
    tenant_id = os.getenv("AZURE_TENANT_ID")
    client_secret = os.getenv("AZURE_CLIENT_SECRET")

    if client_id and not client_secret:
        logger.info("Auth mode: UAMI (client_id=%s...)", client_id[:8])
        return WorkspaceClient(
            host=host,
            azure_use_msi=True,
            azure_client_id=client_id,
        )

    if all([tenant_id, client_id, client_secret]):
        logger.info("Auth mode: SPN (client_id=%s...)", (client_id or "")[:8])
        return WorkspaceClient(
            host=host,
            azure_tenant_id=tenant_id,
            azure_client_id=client_id,
            azure_client_secret=client_secret,
        )

    logger.warning(
        "Auth mode: SAMI (system-assigned MI). "
        "Set AZURE_CLIENT_ID for UAMI or full SPN vars for service principal."
    )
    return WorkspaceClient(
        host=host,
        azure_use_msi=True,
    )
