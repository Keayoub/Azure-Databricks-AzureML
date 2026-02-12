# Terraform Modules

Reusable modules for Unity Catalog and Databricks operational configuration.

## Unity Catalog Modules

### `adb-uc-catalogs`
Creates and manages Unity Catalog catalogs and schemas.

**Features:**
- Multi-catalog support
- Schema creation
- Owner assignment
- Tag propagation

**Usage:**
```terraform
module "uc_catalogs" {
  source = "../modules/adb-uc-catalogs"

  metastore_id = "metastore-id"
  catalogs     = var.catalogs
  tags         = var.tags
}
```

**Documentation:** [adb-uc-catalogs/README.md](./adb-uc-catalogs/README.md)

---

### `adb-uc-volumes`
Creates and manages Unity Catalog external volumes.

**Features:**
- External volume creation
- Storage credential linking
- Volume permissions
- Lifecycle management

**Usage:**
```terraform
module "uc_volumes" {
  source = "../modules/adb-uc-volumes"

  volumes = var.volumes
  tags    = var.tags
}
```

**Documentation:** [adb-uc-volumes/README.md](./adb-uc-volumes/README.md)

---

## Operational Configuration Modules

### `adb-workspace-config`
Configure workspace-level settings and features.

**Features:**
- Unity Catalog enablement
- Serverless compute configuration
- Token lifetime management
- IP access lists
- Global init scripts
- Admin group management

**Usage:**
```terraform
module "workspace_config" {
  source = "../modules/adb-workspace-config"

  enable_unity_catalog      = true
  enable_serverless_compute = true
  max_token_lifetime_days   = 90
  tags                      = var.tags
}
```

**Documentation:** [adb-workspace-config/README.md](./adb-workspace-config/README.md)

---

### `adb-cluster-policies`
Create and manage cluster policies for cost control and security.

**Pre-built Policies:**
- Personal Compute (max 4 workers)
- Shared Compute (max 10 workers)
- Production Jobs (autoscaling 2-50)
- High Concurrency (SQL analytics)

**Features:**
- Cost controls (max workers, auto-termination)
- Security hardening
- VM type restrictions
- Permission management

**Usage:**
```terraform
module "cluster_policies" {
  source = "../modules/adb-cluster-policies"

  environment_name         = "prod"
  enable_cost_controls     = true
  max_workers_limit        = 50
  auto_termination_minutes = 30
  tags                     = var.tags
}
```

**Documentation:** [adb-cluster-policies/README.md](./adb-cluster-policies/README.md)

---

### `adb-instance-pools`
Create instance pools for faster cluster startup and cost optimization.

**Pre-built Pools:**
- General Purpose (balanced)
- High Memory (memory-intensive)
- Compute Optimized (CPU-heavy)
- GPU (ML training)

**Features:**
- Spot instance support (60-80% savings)
- Idle instance auto-termination
- Preloaded Spark versions
- Permission management

**Usage:**
```terraform
module "instance_pools" {
  source = "../modules/adb-instance-pools"

  environment_name      = "prod"
  enable_spot_instances = true
  general_purpose_min_idle = 2
  tags                  = var.tags
}
```

**Documentation:** [adb-instance-pools/README.md](./adb-instance-pools/README.md)

---

### `adb-secret-scopes`
Manage Databricks secret scopes for secure credential storage.

**Scope Types:**
- Databricks-backed (encrypted storage)
- Azure Key Vault-backed (enterprise integration)

**Pre-configured Scopes:**
- Application secrets
- Data source credentials
- API keys

**Features:**
- Fine-grained ACL management
- Secret storage and rotation
- Azure Key Vault integration
- Group-based permissions

**Usage:**
```terraform
module "secret_scopes" {
  source = "../modules/adb-secret-scopes"

  environment_name                 = "prod"
  create_application_secrets_scope = true
  create_data_sources_scope        = true
  tags                             = var.tags
}
```

**Documentation:** [adb-secret-scopes/README.md](./adb-secret-scopes/README.md)

---

## Module Dependencies

- **Databricks Provider**: `~> 1.0`
- **Azure Provider**: `~> 3.0` (for Key Vault integration)
- **Terraform**: `>= 1.0`

## Quick Reference

| Module | Purpose | Cost Impact | Startup Time |
|--------|---------|-------------|--------------|
| uc-catalogs | Data organization | None | N/A |
| uc-volumes | External storage | Storage costs | N/A |
| workspace-config | Settings management | None | N/A |
| cluster-policies | Cost control | -30 to -50% | N/A |
| instance-pools | Performance | -20 to -50% | -60 to -80% |
| secret-scopes | Credential mgmt | None | N/A |

## Testing Modules

```powershell
# Validate a module
cd modules/adb-cluster-policies
terraform init
terraform validate

# Format code
terraform fmt -recursive

# Check for issues
terraform plan
```

## Module Development Guidelines

1. **Naming**: Use `adb-` prefix for Databricks modules
2. **Variables**: Include validation rules
3. **Outputs**: Expose IDs and names
4. **Documentation**: Include README with examples
5. **Tags**: Support tag propagation
6. **Idempotency**: Safe to run multiple times

## Getting Started

**For Unity Catalog:**
- Start with [adb-uc-catalogs](./adb-uc-catalogs/README.md)

**For Operational Config:**
- Review [OPERATIONAL-CONFIG-QUICKSTART.md](../docs/OPERATIONAL-CONFIG-QUICKSTART.md)
- Read [OPERATIONAL-CONFIGURATION.md](../docs/OPERATIONAL-CONFIGURATION.md)
