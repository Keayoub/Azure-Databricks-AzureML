# AzureML → Databricks Authentication

## File Structure

```text
aml_databricks/
├── auth.py                  # Credential resolution (UAMI / SPN / SAMI)
├── databricks_client.py     # HTTP client for Model Serving endpoints
├── pipeline_step.py         # AzureML job entry point
├── pipeline_definition.py   # AzureML SDK v2 pipeline submission
├── requirements.txt
└── README.md
```

## Auth Decision Logic

```text
AZURE_CLIENT_ID set, AZURE_CLIENT_SECRET not set  →  UAMI  (production)
AZURE_CLIENT_ID + AZURE_TENANT_ID + SECRET all set →  SPN   (dev/CI)
Nothing set                                        →  SAMI  (fallback)
```

## Environment Variables

### Inside AzureML Job (set via pipeline_definition.py environment_variables)

| Variable | Required | Description |
| --- | --- | --- |
| `AZURE_CLIENT_ID` | Yes | UAMI client ID (triggers UAMI auth path) |
| `DATABRICKS_HOST` | Yes | e.g. `https://adb-xxxx.azuredatabricks.net` |
| `DATABRICKS_ENDPOINT_NAME` | Yes | Name of the Model Serving endpoint |
| `DATABRICKS_SAMPLE_INPUT_JSON` | No | Optional default payload override |

### For pipeline submission (local / CI)

| Variable | Required | Description |
| --- | --- | --- |
| `AZURE_SUBSCRIPTION_ID` | Yes | Azure subscription |
| `AZURE_RESOURCE_GROUP` | Yes | Resource group of AzureML workspace |
| `AZUREML_WORKSPACE_NAME` | Yes | AzureML workspace name |
| `AZURE_CLIENT_ID` | Yes | UAMI client ID |
| `DATABRICKS_HOST` | Yes | Databricks workspace URL |
| `DATABRICKS_ENDPOINT_NAME` | Yes | Serving endpoint name |
| `AZUREML_COMPUTE_NAME` | No | Defaults to `cpu-cluster` |

## Infra Provisioning Checklist

### 1. Create UAMI

- Create a User-Assigned Managed Identity in the same subscription
- Note the `client_id` (used as `AZURE_CLIENT_ID`)

### 2. Assign UAMI to AzureML Compute

- On the compute cluster or compute instance → Identity → Add UAMI

### 3. Register UAMI in Databricks Workspace

- Workspace Settings → Identity & Access → Service Principals → Add
- Use the UAMI Object ID (not client_id)

### 4. Grant Databricks Permissions to UAMI

```sql
-- Unity Catalog
GRANT USE CATALOG ON CATALOG <catalog> TO `<uami-object-id>`;
GRANT USE SCHEMA ON SCHEMA <catalog>.<schema> TO `<uami-object-id>`;
GRANT SELECT ON TABLE <catalog>.<schema>.<table> TO `<uami-object-id>`;
GRANT MODIFY ON TABLE <catalog>.<schema>.<table> TO `<uami-object-id>`;

-- Model Serving endpoint (if using endpoint-level ACL)
-- Grant "Can Query" on the serving endpoint via Databricks UI or API
```

### 5. No Key Vault secrets needed

- UAMI auth is fully secret-less
- Token is issued by Azure AD at job runtime via IMDS
