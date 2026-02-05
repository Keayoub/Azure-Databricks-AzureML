# adb-uc-metastore

Terraform module for creating Azure Databricks Unity Catalog metastore infrastructure on Azure.

## Module content

This module provisions:

* Azure Data Lake Storage Gen2 account for UC metastore
* Databricks Access Connector for managed identity authentication
* Unity Catalog metastore registration with Azure Databricks
* RBAC assignments for secure access

## How to use

1. Reference this module in your Terraform configuration
2. Provide required variables (see below)
3. Run `terraform init` to initialize Terraform
4. Run `terraform apply` to create the resources

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9.0 |
| azurerm | >=4.0.0 |
| databricks | >=1.52.0 |

## Providers

| Name | Version |
|------|---------|
| azurerm | >=4.0.0 |
| databricks | >=1.52.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `metastore_storage_name` | Name of the ADLS Gen2 storage account for UC metastore | `string` | n/a | yes |
| `metastore_name` | Name of the Databricks Unity Catalog metastore | `string` | n/a | yes |
| `access_connector_name` | Name of the Databricks Access Connector | `string` | n/a | yes |
| `resource_group_name` | Name of the Azure resource group | `string` | n/a | yes |
| `location` | Azure region for resources | `string` | n/a | yes |
| `tags` | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| metastore_id | ID of the created UC metastore |
| metastore_name | Name of the UC metastore |
| storage_account_name | Name of the storage account |
| access_connector_id | ID of the Access Connector |
| access_connector_principal_id | Principal ID of the Access Connector managed identity |

## Example

```hcl
module "adb-uc-metastore" {
  source                     = "./modules/adb-uc-metastore"
  
  metastore_storage_name     = "adlsmetastore"
  metastore_name             = "uc_metastore_prod"
  access_connector_name      = "adb_access_connector"
  resource_group_name        = azurerm_resource_group.example.name
  location                   = azurerm_resource_group.example.location
  
  tags = {
    Environment = "Production"
    Project     = "DataLakehouse"
  }

  providers = {
    databricks = databricks.account
  }
}
```

## Notes

- The metastore uses an Access Connector for secure authentication without exposing storage keys
- ADLS Gen2 requires hierarchical namespace enabled
- Requires Databricks account-level provider configuration
