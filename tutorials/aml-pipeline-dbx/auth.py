"""
auth.py
-------
Authentication module for AzureML -> Databricks connectivity.
Supports UAMI (production) and SPN (dev/CI) credential paths.
No secrets in code. All config via environment variables or Azure Key Vault.
"""

import logging
import os
from dataclasses import dataclass
from enum import Enum, auto
from typing import Optional

from azure.core.credentials import AccessToken
from azure.core.exceptions import ClientAuthenticationError
from azure.identity import ClientSecretCredential, ManagedIdentityCredential

logger = logging.getLogger(__name__)

# Databricks Azure AD resource ID (fixed, do not change)
DATABRICKS_RESOURCE_SCOPE = "2ff814a6-3304-4ab8-85cb-cd0e6f879c1d/.default"


class AuthMode(Enum):
    UAMI = auto()       # User-Assigned Managed Identity (production)
    SPN = auto()        # Service Principal with secret (dev / CI)
    SAMI = auto()       # System-Assigned Managed Identity (fallback)


@dataclass(frozen=True)
class AuthConfig:
    mode: AuthMode
    uami_client_id: Optional[str] = None    # Required for UAMI
    spn_tenant_id: Optional[str] = None     # Required for SPN
    spn_client_id: Optional[str] = None     # Required for SPN
    spn_client_secret: Optional[str] = None # Required for SPN

    @classmethod
    def from_environment(cls) -> "AuthConfig":
        """
        Resolve auth config from environment variables.
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
            logger.info("Auth mode resolved: UAMI (client_id=%s...)", client_id[:8])
            return cls(mode=AuthMode.UAMI, uami_client_id=client_id)

        if all([tenant_id, client_id, client_secret]):
            logger.info("Auth mode resolved: SPN (client_id=%s...)", client_id[:8])
            return cls(
                mode=AuthMode.SPN,
                spn_tenant_id=tenant_id,
                spn_client_id=client_id,
                spn_client_secret=client_secret,
            )

        logger.warning(
            "Auth mode resolved: SAMI (system-assigned MI). "
            "Set AZURE_CLIENT_ID for UAMI or full SPN vars for service principal."
        )
        return cls(mode=AuthMode.SAMI)


class DatabricksTokenProvider:
    """
    Obtains and caches a short-lived Azure AD token scoped to Databricks.
    Handles token refresh transparently.
    """

    def __init__(self, config: AuthConfig):
        self._config = config
        self._credential = self._build_credential()
        self._cached_token: Optional[AccessToken] = None

    def _build_credential(self):
        mode = self._config.mode

        if mode == AuthMode.UAMI:
            return ManagedIdentityCredential(
                client_id=self._config.uami_client_id
            )

        if mode == AuthMode.SPN:
            return ClientSecretCredential(
                tenant_id=self._config.spn_tenant_id,
                client_id=self._config.spn_client_id,
                client_secret=self._config.spn_client_secret,
            )

        if mode == AuthMode.SAMI:
            return ManagedIdentityCredential()

        raise ValueError(f"Unsupported AuthMode: {mode}")

    def get_token(self) -> str:
        """
        Returns a valid bearer token string, refreshing if expired.
        azure-identity handles expiry automatically but we surface errors clearly.
        """
        try:
            self._cached_token = self._credential.get_token(DATABRICKS_RESOURCE_SCOPE)
            logger.debug("Token acquired, expires at %s", self._cached_token.expires_on)
            return self._cached_token.token
        except ClientAuthenticationError as e:
            logger.error(
                "Failed to acquire Databricks token in mode=%s: %s",
                self._config.mode.name, e,
            )
            raise
