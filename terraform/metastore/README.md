# Unity Catalog Metastore Layer

## Purpose
One-time metastore creation per region. Runs during `azd provision`.

## What It Does
1. Checks if metastore already exists in region
2. Creates metastore if doesn't exist (or uses existing)
3. Configures data access with managed identity
4. Assigns metastore to workspace

## When It Runs
- **Hook**: `postprovision` (after Bicep deployment)
- **Command**: `azd provision`
- **Trigger**: Automatically via `infra/scripts/postprovision.ps1`

## Manual Execution
```powershell
cd terraform/metastore
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## State Management
- Creates/uses metastore (one per region)
- Idempotent: safe to run multiple times
- Uses `count = 0` if metastore exists

## Next Steps
After metastore is created, deploy UC components via `azd deploy`.
