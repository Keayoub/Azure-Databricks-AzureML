# adb-uc-volumes

Terraform module for creating Databricks Unity Catalog volumes.

## Overview

This module provisions UC volumes for structured data storage:
- External volumes linked to ADLS/cloud storage
- Managed volumes for Databricks-managed storage
- Volume ownership assignment
- Granular permissions via grants

## Module content

This module creates:

- **Volumes** - Structured storage within schemas
- **Volume Grants** - Owner assignments to volumes

## How to use

1. Reference this module using a module source
2. Define volumes with catalog and schema references
3. Run `terraform init` to initialize Terraform
4. Run `terraform plan` to see the resources
5. Run `terraform apply` to create the resources

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `volumes` | Map of volume definitions to create | `map(object({...}))` | n/a | yes |
| `tags` | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `volumes` | Map of created volumes with details |

## Example

```hcl
module "adb-uc-volumes" {
  source = "./modules/adb-uc-volumes"

  volumes = {
    data_ingestion = {
      catalog_name = "main"
      schema_name  = "raw"
      name         = "data_ingestion"
      comment      = "Volume for data ingestion"
      owner        = "data-engineers@company.com"
    }
    analytics_output = {
      catalog_name = "analytics"
      schema_name  = "reports"
      name         = "output"
      comment      = "Volume for analytics output"
      owner        = "analytics@company.com"
    }
  }

  tags = {
    Environment = "Production"
  }

  providers = {
    databricks = databricks.workspace
  }
}
```

## Requirements

- Terraform >= 1.9.0
- Databricks Provider >= 1.52
- Databricks workspace-level provider
- Target catalogs and schemas must exist

## Notes

- Volumes are created with `volume_type = "EXTERNAL"` by default
- Owner assignment is optional
- All volumes must belong to existing catalog.schema
- Requires workspace-level Databricks provider
