# Terraform Documentation Index

Quick links to help you navigate Terraform resources in this project.

## 📖 Core Documentation

1. **[TERRAFORM-README.md](TERRAFORM-README.md)** - Start here! Explains:
   - Two-layer architecture (metastore + environments)
   - Quick start for automated and manual deployment
   - Troubleshooting guide
   - Best practices

2. **[docs/TERRAFORM-QUICK-START.md](docs/TERRAFORM-QUICK-START.md)** - Get started quickly
   - Basic setup and initialization
   - Running your first deployment
   - Common commands

3. **[docs/TERRAFORM-QUICK-REFERENCE.md](docs/TERRAFORM-QUICK-REFERENCE.md)** - Reference guide
   - Command cheatsheet
   - Variable definitions
   - Output descriptions

## 🏗️ Modules

### Catalogs Module

Create and manage Unity Catalogs, schemas, and ownership.

- **Location:** `modules/adb-uc-catalogs/`
- **Documentation:** [modules/adb-uc-catalogs/README.md](modules/adb-uc-catalogs/README.md)
- **Use case:** Define your medallion architecture (bronze, silver, gold)

### Volumes Module

Create external volumes and storage credentials.

- **Location:** `modules/adb-uc-volumes/`
- **Documentation:** [modules/adb-uc-volumes/README.md](modules/adb-uc-volumes/README.md)
- **Use case:** Mount external storage (ADLS Gen2, S3) as Databricks volumes

### Metastore Module

Create Unity Catalog metastore (account-level).

- **Location:** `metastore/`
- **Files:** `main.tf`, `variables.tf`, `outputs.tf`, `providers.tf`
- **Use case:** One-time setup per region

## 🎯 Common Tasks

### Deploy Everything Automatically
```bash
azd provision  # Creates infrastructure + metastore
azd deploy     # Creates catalogs and volumes
```

### Create a New Catalog
Edit `terraform/environments/main.tf`:
```hcl
module "uc-catalogs" {
  # ... existing module ...
  
  catalogs = {
    # ... existing catalogs ...
    new_team_catalog = {
      name    = "new_team_catalog"
      comment = "New team workspace"
      schemas = {
        bronze = { name = "bronze" }
        silver = { name = "silver" }
        gold   = { name = "gold" }
      }
    }
  }
}
```

### Create a New Volume
Edit `terraform/environments/main.tf`:
```hcl
module "uc-volumes" {
  # ... existing module ...
  
  catalogs = {
    # ... existing catalogs ...
    team_catalog = {
      volume_name = "new-volume"
      # ... other properties ...
    }
  }
}
```

### Plan Changes
```bash
cd terraform/environments
terraform plan -out=tfplan
```

### Apply Specific Resource
```bash
terraform apply -target=databricks_catalog.my_catalog
```

## 📂 File Organization

```
terraform/
├── INDEX.md                          # This file (you are here)
├── TERRAFORM-README.md               # Main documentation
├── README.md                         # (Legacy, see TERRAFORM-README.md)
│
├── docs/
│   ├── TERRAFORM-QUICK-START.md      # Getting started
│   ├── TERRAFORM-QUICK-REFERENCE.md  # Command reference
│   └── DEPLOYMENT.md                 # Deployment guide
│
├── metastore/                        # Layer 1: Account-level metastore
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── terraform.tf
│
├── environments/                     # Layer 2: Workspace-level UC components
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── terraform.tf
│   └── (terraform.tfvars)
│
└── modules/                          # Reusable Terraform modules
    ├── README.md
    ├── adb-uc-catalogs/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── terraform.tf
    │   ├── README.md
    │   └── examples.tf
    └── adb-uc-volumes/
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        ├── terraform.tf
        ├── README.md
        └── examples.tf
```

## 🔗 Related Documentation

- **[Project README](../README.md)** - Overview of entire project
- **[DEPLOYMENT-PROCESS.md](../docs/DEPLOYMENT-PROCESS.md)** - Complete two-phase deployment guide
- **[Azure Architecture](../docs/design/Azure-Architecture.drawio)** - Visual architecture diagrams
- **[SECURITY-AUDIT.md](../docs/SECURITY-AUDIT.md)** - Security and compliance details

## ❓ Frequently Asked Questions

### Where do I set Terraform variables?

For **initial metastore creation** (one-time):
- Generated automatically by `infra/scripts/postprovision.ps1`
- Location: `terraform/metastore/terraform.tfvars`

For **UC components** (catalogs, schemas):
- Generated automatically by `infra/scripts/postdeploy.ps1`
- Location: `terraform/environments/terraform.tfvars`

### How do I customize catalogs?

Edit `terraform/environments/main.tf` and modify the `catalogs` variable in the `adb-uc-catalogs` module call. Then run:
```bash
cd terraform/environments
terraform plan -out=tfplan
terraform apply tfplan
```

### Can I manage state remotely?

Yes! Create a `backend.tf` file in `terraform/metastore/` or `terraform/environments/`:
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"
    container_name       = "state"
    key                  = "metastore.tfstate"
  }
}
```

Then run: `terraform init` to migrate state.

### How do I destroy resources?

**Destroy catalogs only (keep metastore):**
```bash
cd terraform/environments
terraform destroy
```

**Destroy everything:**
```bash
cd terraform/environments
terraform destroy

cd ../metastore
terraform destroy
```

⚠️ **Warning:** Destroying resources deletes data in external volumes!

### Where's my Terraform state?

By default, state is stored **locally**:
- `terraform/metastore/.terraform/terraform.tfstate`
- `terraform/environments/.terraform/terraform.tfstate`

These files are **excluded from Git** (see `.gitignore`).

### How do I share state with my team?

See FAQ: "Can I manage state remotely?" above.

## 📞 Getting Help

1. Check [TERRAFORM-README.md](TERRAFORM-README.md#troubleshooting)
2. Review [Deployment Process guide](../docs/DEPLOYMENT-PROCESS.md)
3. Check Terraform logs: `cat terraform.log`
4. Run validation: `terraform validate && terraform fmt -recursive -check`

## 🚀 Next Steps

1. **Read** [TERRAFORM-README.md](TERRAFORM-README.md) for full overview
2. **Review** your catalogs in `terraform/environments/main.tf`
3. **Plan** changes: `terraform plan -out=tfplan`
4. **Apply** safely: `terraform apply tfplan`
5. **Monitor** in Databricks workspace admin console
