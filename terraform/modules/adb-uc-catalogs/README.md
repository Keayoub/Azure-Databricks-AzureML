# adb-uc-catalogs

Terraform module for creating Databricks Unity Catalog catalogs and schemas.

## Overview

This module provisions Unity Catalog data organization structures:
- Multiple catalogs for data segregation
- Schemas within catalogs for logical organization
- Catalog and schema ownership assignment
- Granular permissions via grants

## Module content

This module creates:

- **Catalogs** - Top-level organizational containers
- **Schemas** - Collections of tables within catalogs
- **Catalog Grants** - Owner assignments to catalogs
- **Schema Grants** - Owner assignments to schemas

## How to use

1. Reference this module using a module source
2. Define catalogs with nested schemas in `var.catalogs`
3. Run `terraform init` to initialize Terraform
4. Run `terraform plan` to see the resources to be created
5. Run `terraform apply` to create the resources

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `metastore_id` | ID of the UC metastore | `string` | n/a | yes |
| `catalogs` | Map of catalog definitions to create | `map(object({...}))` | n/a | yes |
| `tags` | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `catalogs` | Map of created catalogs with IDs |
| `schemas` | Map of created schemas with IDs |

## Example

```hcl
module "adb-uc-catalogs" {
  source = "./modules/adb-uc-catalogs"

  metastore_id = module.adb-uc-metastore.metastore_id
  
  catalogs = {
    main = {
      name    = "main"
      comment = "Default catalog"
      owner   = "data-engineers@company.com"
      schemas = {
        default = {
          name    = "default"
          comment = "Default schema"
        }
        raw = {
          name    = "raw"
          comment = "Raw data schema"
          owner   = "data-ingestion@company.com"
        }
      }
    }
    analytics = {
      name    = "analytics"
      comment = "Analytics catalog"
      schemas = {
        reports = {
          name    = "reports"
          comment = "Report schemas"
        }
      }
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
- Metastore assigned to workspace

## Notes

- Catalogs and schemas are created with `force_destroy = true`
- Owner assignment is optional
- All schemas must belong to an existing catalog
- Requires workspace-level Databricks provider
