# Databricks Secret Scopes Module

## Overview

This module creates and manages Databricks secret scopes for secure credential storage. Supports both Databricks-backed and Azure Key Vault-backed scopes.

## Secret Scope Types

### 1. Databricks-Backed Scopes
- Secrets stored in Databricks' encrypted storage
- Managed entirely within Databricks
- Simple setup, no external dependencies
- **Best for**: Application secrets, temporary credentials

### 2. Azure Key Vault-Backed Scopes
- Secrets stored in Azure Key Vault
- Referenced from Databricks
- Centralized secret management
- **Best for**: Production secrets, compliance requirements

## Features

- **Pre-configured Scopes**: Common patterns ready to use
- **ACL Management**: Fine-grained permission control
- **Secret Management**: Store and rotate secrets
- **Integration**: Works with Azure Key Vault

## Usage

### Databricks-Backed Scopes

```hcl
module "secret_scopes" {
  source = "../modules/adb-secret-scopes"

  environment_name = "prod"

  # Databricks-backed scopes with secrets
  databricks_backed_scopes = {
    "db-credentials" = {
      secrets = {
        "postgres-username" = "admin"
        "postgres-password" = var.postgres_password  # From variable
      }
      acls = [
        {
          principal  = "data-engineers"
          permission = "READ"
        },
        {
          principal  = "admins"
          permission = "MANAGE"
        }
      ]
    }
  }

  # Pre-configured scopes
  create_application_secrets_scope = true
  application_secrets_acls = {
    dev_team = {
      principal  = "developers"
      permission = "READ"
    }
  }

  tags = {
    ManagedBy = "Terraform"
  }
}
```

### Azure Key Vault-Backed Scopes

```hcl
# First, ensure your Azure Key Vault exists (from Bicep)
# Then reference it in Terraform

module "secret_scopes" {
  source = "../modules/adb-secret-scopes"

  environment_name = "prod"

  keyvault_backed_scopes = {
    "production-secrets" = {
      keyvault_resource_id = data.azurerm_key_vault.main.id
      keyvault_dns_name    = data.azurerm_key_vault.main.vault_uri
      acls = [
        {
          principal  = "data-engineers"
          permission = "READ"
        }
      ]
    }
  }
}

# Reference existing Key Vault
data "azurerm_key_vault" "main" {
  name                = "kv-prod-myproject"
  resource_group_name = "rg-prod-shared"
}
```

### Using Secrets in Notebooks

**Databricks-backed:**
```python
# Python
username = dbutils.secrets.get(scope="db-credentials", key="postgres-username")
password = dbutils.secrets.get(scope="db-credentials", key="postgres-password")

# Secrets are redacted in logs
print(username)  # Output: admin
print(password)  # Output: [REDACTED]
```

**Spark Config:**
```python
spark.conf.set(
    "fs.azure.account.key.<storage-account>.dfs.core.windows.net",
    dbutils.secrets.get(scope="data-sources", key="storage-account-key")
)
```

## Pre-configured Scopes

### Application Secrets
```hcl
create_application_secrets_scope = true
application_secrets_acls = {
  dev_team = {
    principal  = "developers"
    permission = "READ"
  }
}
```

**Use for**: API tokens, service credentials, feature flags

### Data Sources
```hcl
create_data_sources_scope = true
data_sources_acls = {
  data_engineers = {
    principal  = "data-engineers"
    permission = "READ"
  }
}
```

**Use for**: Database connection strings, storage keys

### API Keys
```hcl
create_api_keys_scope = true
api_keys_acls = {
  ml_team = {
    principal  = "ml-engineers"
    permission = "READ"
  }
}
```

**Use for**: External API keys, third-party integrations

## Permission Levels

| Permission | Description | Use Case |
|------------|-------------|----------|
| `READ` | Read secrets only | Normal users |
| `WRITE` | Read and add/update secrets | Service accounts |
| `MANAGE` | Full control including ACL changes | Administrators |

## Variables

| Name | Description | Default | Required |
|------|-------------|---------|----------|
| `environment_name` | Environment (dev/staging/prod) | - | Yes |
| `databricks_backed_scopes` | Databricks-backed scopes config | `{}` | No |
| `keyvault_backed_scopes` | Key Vault-backed scopes config | `{}` | No |
| `create_application_secrets_scope` | Create app secrets scope | `true` | No |

## Outputs

| Name | Description |
|------|-------------|
| `databricks_backed_scopes` | Databricks-backed scope names |
| `keyvault_backed_scopes` | Key Vault-backed scope names |
| `all_scopes` | All scope names |

## Security Best Practices

### Secret Management
1. **Never commit secrets to Git**: Use variables or Key Vault
2. **Rotate regularly**: Implement rotation schedules
3. **Least privilege**: Grant READ only when possible
4. **Audit access**: Monitor secret scope usage

### ACL Configuration
```hcl
# Good: Group-based permissions
acls = [
  {
    principal  = "data-engineers"
    permission = "READ"
  }
]

# Avoid: User-based permissions (harder to manage)
acls = [
  {
    principal  = "user@example.com"
    permission = "READ"
  }
]
```

### Sensitive Variables
```hcl
# In terraform.tfvars (not committed)
postgres_password = "supersecret"

# Or use environment variables
export TF_VAR_postgres_password="supersecret"

# Or fetch from Key Vault
data "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-password"
  key_vault_id = data.azurerm_key_vault.main.id
}
```

## Common Patterns

### Database Credentials
```hcl
databricks_backed_scopes = {
  "database-prod" = {
    secrets = {
      "sql-server-host"     = "sqlserver.database.windows.net"
      "sql-server-username" = "sqladmin"
      "sql-server-password" = var.sql_password
      "sql-server-database" = "analytics"
    }
    acls = [
      {
        principal  = "data-engineers"
        permission = "READ"
      }
    ]
  }
}
```

### Storage Account Keys
```hcl
databricks_backed_scopes = {
  "storage-accounts" = {
    secrets = {
      "bronze-storage-key" = var.bronze_storage_key
      "silver-storage-key" = var.silver_storage_key
      "gold-storage-key"   = var.gold_storage_key
    }
    acls = [
      {
        principal  = "etl-service-principal"
        permission = "READ"
      }
    ]
  }
}
```

### External API Keys
```hcl
databricks_backed_scopes = {
  "external-apis" = {
    secrets = {
      "openai-api-key"      = var.openai_key
      "azure-maps-key"      = var.azure_maps_key
      "sendgrid-api-key"    = var.sendgrid_key
    }
    acls = [
      {
        principal  = "ml-engineers"
        permission = "READ"
      }
    ]
  }
}
```

## Choosing Scope Type

### Use Databricks-Backed When:
- Development environments
- Simple credential management
- No compliance requirements for external storage
- Secrets managed by data team only

### Use Key Vault-Backed When:
- Production environments
- Compliance requirements (SOC2, HIPAA, etc.)
- Centralized secret management across services
- Integration with Azure security center
- Secret rotation policies required

## Troubleshooting

### Secret Not Found
```python
# Error: Secret does not exist with scope: xyz and key: abc

# Solution: Verify scope and key names
dbutils.secrets.listScopes()
dbutils.secrets.list(scope="xyz")
```

### Permission Denied
```
# Error: User does not have READ permission on secret scope

# Solution: Check ACLs
```

### Key Vault Access Issues
```
# Error: Key Vault not found or access denied

# Solution: Verify:
# 1. Key Vault resource ID is correct
# 2. Databricks service principal has Get/List permissions
# 3. DNS name includes https:// and trailing /
```

## Migration Guide

### From Manual Scopes to Terraform

1. **List existing scopes:**
   ```bash
   databricks secrets list-scopes
   ```

2. **Import into Terraform:**
   ```bash
   terraform import databricks_secret_scope.existing_scope scope-name
   ```

3. **Import ACLs:**
   ```bash
   terraform import databricks_secret_acl.existing_acl scope-name|||principal-name
   ```

## References

- [Databricks Secret Management](https://docs.databricks.com/en/security/secrets/index.html)
- [Secret Scopes](https://docs.databricks.com/en/security/secrets/secret-scopes.html)
- [Azure Key Vault Integration](https://docs.databricks.com/en/security/secrets/secret-scopes.html#azure-key-vault-backed-scopes)
- [Secret ACLs](https://docs.databricks.com/en/security/secrets/secret-acl.html)
