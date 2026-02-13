# Databricks Operational Configuration

## Overview

This guide covers the operational configuration modules for Databricks workspaces, including:

1. **Workspace Configuration** - Workspace settings, IP access lists, init scripts
2. **Cluster Policies** - Cost controls and security enforcement
3. **Instance Pools** - Faster cluster startup and cost optimization
4. **Secret Scopes** - Secure credential management

## Quick Start

### 1. Enable Operational Configuration

Edit `terraform/environments/terraform.tfvars`:

```hcl
# Enable operational modules
enable_workspace_configuration = true
enable_cluster_policies        = true
enable_instance_pools          = true
enable_secret_scopes           = true
```

### 2. Deploy

```bash
cd terraform/environments
terraform plan
terraform apply
```

## Module Details

### Workspace Configuration

Configures workspace-level settings including Unity Catalog, serverless compute, and token management.

**Key Features:**
- Unity Catalog enablement
- Serverless compute configuration
- Token lifetime limits
- IP access lists (optional)
- Global init scripts (optional)

**Example:**
```hcl
enable_workspace_configuration = true
enable_serverless_compute      = true
max_token_lifetime_days        = 90
```

**Documentation:** [Workspace Config Module](../modules/adb-workspace-config/README.md)

---

### Cluster Policies

Enforce cost controls and security standards across all clusters.

**Pre-built Policies:**
- **Personal Compute** - Individual development (max 4 workers, 30min timeout)
- **Shared Compute** - Team collaboration (max 10 workers, 60min timeout)
- **Production Jobs** - Batch processing (autoscaling 2-50 workers)
- **High Concurrency** - SQL analytics (up to 20 workers)

**Cost Controls:**
- Maximum worker limits
- Mandatory auto-termination
- Restricted VM types
- Cost center tagging

**Example:**
```hcl
enable_cluster_policies        = true
create_personal_compute_policy = true
create_production_jobs_policy  = true
enable_cost_controls           = true
max_workers_limit              = 50
auto_termination_minutes       = 30
```

**Documentation:** [Cluster Policies Module](../modules/adb-cluster-policies/README.md)

---

### Instance Pools

Reduce cluster startup time by maintaining pools of ready-to-use instances.

**Pre-built Pools:**
- **General Purpose** - Balanced resources (Standard_DS3_v2)
- **High Memory** - Memory-intensive workloads (Standard_E8s_v3)
- **Compute Optimized** - CPU-intensive ETL (Standard_F8s_v2)
- **GPU** - ML training (Standard_NC6s_v3)

**Benefits:**
- 60-80% faster cluster startup
- Up to 50% cost savings with spot instances
- Guaranteed capacity for critical workloads

**Example:**
```hcl
enable_instance_pools       = true
create_general_purpose_pool = true
general_purpose_min_idle    = 2
enable_spot_instances       = true  # Dev only!
```

**Documentation:** [Instance Pools Module](../modules/adb-instance-pools/README.md)

---

### Secret Scopes

Secure storage for credentials, API keys, and connection strings.

Key Vault architecture options and Databricks secret scope guidance:
[DATABRICKS-KEYVAULT-ARCHITECTURE-GUIDE.md](../../docs/DATABRICKS-KEYVAULT-ARCHITECTURE-GUIDE.md)

**Scope Types:**
- **Databricks-Backed** - Encrypted storage in Databricks
- **Azure Key Vault-Backed** - Enterprise secret management

**Pre-configured Scopes:**
- `{env}-app-secrets` - Application credentials
- `{env}-data-sources` - Database connection strings
- `{env}-api-keys` - External API keys

**Example:**
```hcl
enable_secret_scopes             = true
create_application_secrets_scope = true
create_data_sources_scope        = true

application_secrets_acls = {
  developers = {
    principal  = "developers"
    permission = "READ"
  }
}
```

**Documentation:** [Secret Scopes Module](../modules/adb-secret-scopes/README.md)

---

## Configuration Examples

### Development Environment

**Optimized for:** Cost savings, flexibility

```hcl
# terraform/environments/dev.tfvars

environment_name = "dev"

# Workspace Config
enable_workspace_configuration = true
enable_serverless_compute      = true
max_token_lifetime_days        = 90

# Cluster Policies (cost-optimized)
enable_cluster_policies        = true
create_personal_compute_policy = true
create_shared_compute_policy   = true
enable_cost_controls           = true
max_workers_limit              = 10
auto_termination_minutes       = 15

# Instance Pools (spot instances for savings)
enable_instance_pools                 = true
create_general_purpose_pool           = true
general_purpose_min_idle              = 0
general_purpose_max_capacity          = 5
enable_spot_instances                 = true
azure_availability                    = "SPOT_WITH_FALLBACK_AZURE"
idle_instance_autotermination_minutes = 10

# Secret Scopes
enable_secret_scopes             = true
create_application_secrets_scope = true
create_data_sources_scope        = true
```

### Production Environment

**Optimized for:** Reliability, security, performance

```hcl
# terraform/environments/prod.tfvars

environment_name = "prod"

# Workspace Config
enable_workspace_configuration = true
enable_serverless_compute      = true
max_token_lifetime_days        = 90
enable_ip_access_lists         = true
ip_access_lists = {
  corporate_vpn = {
    list_type    = "ALLOW"
    ip_addresses = ["203.0.113.0/24"]
    enabled      = true
  }
}

# Cluster Policies (production-grade)
enable_cluster_policies          = true
create_personal_compute_policy   = false  # Disable personal in prod
create_shared_compute_policy     = true
create_production_jobs_policy    = true
enable_cost_controls             = true
enable_security_hardening        = true
max_workers_limit                = 50
auto_termination_minutes         = 30

production_jobs_permissions = [
  {
    group_name       = "data-engineers"
    permission_level = "CAN_USE"
  }
]

# Instance Pools (guaranteed capacity)
enable_instance_pools                 = true
create_general_purpose_pool           = true
general_purpose_min_idle              = 2  # Pre-warmed instances
general_purpose_max_capacity          = 20
enable_spot_instances                 = false  # On-demand only
azure_availability                    = "ON_DEMAND_AZURE"
idle_instance_autotermination_minutes = 30

# Secret Scopes (Key Vault-backed for compliance)
enable_secret_scopes = true
keyvault_backed_scopes = {
  "production-secrets" = {
    keyvault_resource_id = "/subscriptions/<sub-id>/resourceGroups/rg-prod-shared/providers/Microsoft.KeyVault/vaults/kv-prod"
    keyvault_dns_name    = "https://kv-prod.vault.azure.net/"
    acls = [
      {
        principal  = "admins"
        permission = "MANAGE"
      }
    ]
  }
}
```

---

## Deployment Workflow

### Initial Deployment

```bash
# 1. Navigate to environments directory
cd terraform/environments

# 2. Review configuration
cat terraform.tfvars

# 3. Initialize Terraform (if not already done)
terraform init

# 4. Preview changes
terraform plan

# 5. Apply operational configuration
terraform apply
```

### Updating Configuration

```bash
# 1. Edit terraform.tfvars
vim terraform.tfvars

# 2. Validate changes
terraform validate

# 3. Review plan
terraform plan

# 4. Apply updates
terraform apply
```

### Disable Specific Modules

```bash
# Disable instance pools temporarily
terraform apply -var="enable_instance_pools=false"
```

---

## Best Practices

### Cost Optimization

1. **Use Spot Instances** in dev/staging (60-80% savings)
   ```hcl
   enable_spot_instances = true
   azure_availability    = "SPOT_WITH_FALLBACK_AZURE"
   ```

2. **Set Aggressive Timeouts** for development
   ```hcl
   auto_termination_minutes              = 15
   idle_instance_autotermination_minutes = 10
   ```

3. **Limit Worker Counts** based on actual usage
   ```hcl
   max_workers_limit = 10  # Dev
   max_workers_limit = 50  # Prod
   ```

### Security Hardening

1. **Restrict IP Access** in production
   ```hcl
   enable_ip_access_lists = true
   ```

2. **Use Key Vault-Backed Scopes** for production secrets
   ```hcl
   keyvault_backed_scopes = { ... }
   ```

3. **Enable Security Hardening** in policies
   ```hcl
   enable_security_hardening = true
   ```

4. **Limit Token Lifetime**
   ```hcl
   max_token_lifetime_days = 90
   ```

### Operational Excellence

1. **Use Group-Based Permissions**
   ```hcl
   production_jobs_permissions = [
     { group_name = "data-engineers", permission_level = "CAN_USE" }
   ]
   ```

2. **Pre-warm Pools** for production
   ```hcl
   general_purpose_min_idle = 2
   ```

3. **Tag Everything** for cost allocation
   ```hcl
   tags = {
     Environment = "prod"
     CostCenter  = "DataEngineering"
     Project     = "Analytics"
   }
   ```

---

## Troubleshooting

### Policy Not Visible to Users

**Symptom:** Users don't see cluster policy in workspace

**Solution:**
- Check policy permissions
- Verify user is in correct group
- Confirm policy creation succeeded

```bash
terraform state show 'module.cluster_policies[0].databricks_cluster_policy.personal_compute[0]'
```

### Pool Not Reducing Startup Time

**Symptom:** Clusters still take 5+ minutes to start

**Solution:**
- Verify Spark version matches between pool and cluster
- Check pool has idle instances available
- Ensure pool max capacity not reached

### Secret Not Found

**Symptom:** `Secret does not exist` error

**Solution:**
```python
# List available scopes
dbutils.secrets.listScopes()

# List secrets in scope
dbutils.secrets.list(scope="dev-app-secrets")
```

### IP Access List Lockout

**Symptom:** Cannot access workspace after enabling IP lists

**Solution:**
- Use Azure Portal to modify Databricks workspace
- Or disable via Terraform:
  ```bash
  terraform apply -var="enable_ip_access_lists=false"
  ```

---

## Migration from Manual Configuration

### Import Existing Resources

```bash
# Import cluster policy
terraform import 'module.cluster_policies[0].databricks_cluster_policy.personal_compute[0]' <policy-id>

# Import instance pool
terraform import 'module.instance_pools[0].databricks_instance_pool.general_purpose[0]' <pool-id>

# Import secret scope
terraform import 'module.secret_scopes[0].databricks_secret_scope.application_secrets[0]' <scope-name>
```

---

## Next Steps

1. **Review Modules Documentation** for detailed configuration options
2. **Customize Policies** for your organization's requirements
3. **Set Up Monitoring** for policy compliance and pool utilization
4. **Implement Secret Rotation** for production environments
5. **Create CI/CD Pipelines** for automated Terraform deployments

## References

- [Workspace Config Module](../modules/adb-workspace-config/README.md)
- [Cluster Policies Module](../modules/adb-cluster-policies/README.md)
- [Instance Pools Module](../modules/adb-instance-pools/README.md)
- [Secret Scopes Module](../modules/adb-secret-scopes/README.md)
- [Databricks Best Practices](https://docs.databricks.com/en/administration-guide/index.html)
