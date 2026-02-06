# Terraform Modules

Reusable modules for Unity Catalog components.

## Available Modules

### `adb-uc-catalogs`
Creates and manages Unity Catalog catalogs and schemas.

**Usage:**
```terraform
module "uc_catalogs" {
  source = "../modules/adb-uc-catalogs"

  metastore_id = "metastore-id"
  catalogs     = var.catalogs
  tags         = var.tags
}
```

---

### `adb-uc-volumes`
Creates and manages Unity Catalog external volumes.

**Usage:**
```terraform
module "uc_volumes" {
  source = "../modules/adb-uc-volumes"

  volumes = var.volumes
  tags    = var.tags
}
```

---

## Module Dependencies

- **Databricks Provider**: `~> 1.52`
- **Terraform**: `>= 1.9.0`

## Testing Modules

```powershell
cd modules/adb-uc-catalogs
terraform init
terraform validate
```
