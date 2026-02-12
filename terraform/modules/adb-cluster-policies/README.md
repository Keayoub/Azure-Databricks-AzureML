# Databricks Cluster Policies Module

## Overview

This module creates and manages Databricks cluster policies for cost control, security, and governance.

## Features

### Pre-built Policies

1. **Personal Compute** - Individual development workspaces
   - Max 4 workers
   - 30-minute auto-termination
   - User isolation enabled

2. **Shared Compute** - Team collaboration
   - Max 10 workers
   - 60-minute auto-termination
   - User isolation for multi-user access

3. **Production Jobs** - ETL and batch processing
   - Autoscaling 2-50 workers
   - 10-minute auto-termination
   - Job-only clusters

4. **High Concurrency** - SQL Analytics
   - Up to 20 workers
   - 120-minute auto-termination
   - SQL, Python, R languages

### Cost Controls

- Maximum worker limits
- Mandatory auto-termination
- Restricted VM types
- Cost center tagging

### Security Features

- User isolation mode
- Data security enforcement
- Elastic disk enabled
- Spark configuration hardening

## Usage

```hcl
module "cluster_policies" {
  source = "../modules/adb-cluster-policies"

  environment_name = "prod"

  # Enable built-in policies
  create_personal_compute_policy   = true
  create_shared_compute_policy     = true
  create_production_jobs_policy    = true
  create_high_concurrency_policy   = true

  # Cost controls
  enable_cost_controls      = true
  max_workers_limit         = 50
  auto_termination_minutes  = 30
  default_cost_center       = "DataEngineering"

  # Security hardening
  enable_security_hardening = true

  # Allowed instance types
  allowed_node_types = [
    "Standard_DS3_v2",
    "Standard_DS4_v2",
    "Standard_D8s_v3"
  ]

  # Permissions
  personal_compute_permissions = [
    {
      group_name       = "data-scientists"
      permission_level = "CAN_USE"
    }
  ]

  production_jobs_permissions = [
    {
      group_name       = "data-engineers"
      permission_level = "CAN_USE"
    },
    {
      group_name       = "admins"
      permission_level = "CAN_USE"
    }
  ]

  tags = {
    ManagedBy = "Terraform"
    Owner     = "DataPlatform"
  }
}
```

## Custom Policies

Define custom policies for specific use cases:

```hcl
custom_policies = {
  "ml-training" = {
    description = "GPU clusters for ML training"
    definition = {
      "node_type_id" = {
        type   = "allowlist"
        values = ["Standard_NC6s_v3", "Standard_NC12s_v3"]
      }
      "autoscale.max_workers" = {
        type     = "range"
        maxValue = 10
      }
      "spark_conf.spark.databricks.delta.properties.defaults.enableChangeDataFeed" = {
        type  = "fixed"
        value = "true"
      }
    }
  }
}
```

## Variables

| Name | Description | Default | Required |
|------|-------------|---------|----------|
| `environment_name` | Environment (dev/staging/prod) | - | Yes |
| `create_personal_compute_policy` | Create personal compute policy | `true` | No |
| `create_shared_compute_policy` | Create shared compute policy | `true` | No |
| `create_production_jobs_policy` | Create production jobs policy | `true` | No |
| `max_workers_limit` | Global max workers limit | `50` | No |
| `auto_termination_minutes` | Default auto-termination | `30` | No |
| `allowed_node_types` | Allowed VM types | See vars | No |

## Outputs

| Name | Description |
|------|-------------|
| `personal_compute_policy_id` | Personal compute policy ID |
| `shared_compute_policy_id` | Shared compute policy ID |
| `production_jobs_policy_id` | Production jobs policy ID |
| `all_policy_ids` | Map of all policy IDs |

## Best Practices

### Cost Optimization

1. **Set appropriate limits**: Balance performance with cost
2. **Auto-termination**: Enforce on all policies (5-30 minutes for dev)
3. **Node type restrictions**: Limit to cost-effective VM types
4. **Autoscaling**: Use autoscaling over fixed workers

### Security

1. **User Isolation**: Enable for all multi-user clusters
2. **Data Security Mode**: Choose appropriate level
3. **Language restrictions**: Limit to required languages
4. **Spark configs**: Harden security settings

### Governance

1. **Mandatory tags**: Cost center, project, owner
2. **Policy permissions**: Grant via groups, not users
3. **Regular reviews**: Audit policy usage quarterly
4. **Documentation**: Document policy intent

## Policy Selection Guide

| Workload | Policy | Rationale |
|----------|--------|-----------|
| Exploratory analysis | Personal Compute | Small, short-lived |
| Team notebooks | Shared Compute | Collaborative, medium |
| ETL pipelines | Production Jobs | Autoscaling, job clusters |
| SQL dashboards | High Concurrency | Multi-user SQL |
| ML training | Custom (GPU) | Specialized hardware |

## Common Patterns

### Development Environment
```hcl
auto_termination_minutes = 15
max_workers_limit        = 4
```

### Production Environment
```hcl
auto_termination_minutes = 10
max_workers_limit        = 50
enable_security_hardening = true
```

## Troubleshooting

### Policy Not Appearing
- Check permissions on policy
- Verify user is in allowed group
- Check policy is not hidden

### Cluster Creation Fails
- Review policy definition JSON
- Check node type availability
- Verify autoscaling ranges are valid

### Cost Overruns
- Review max_workers settings
- Check auto-termination is enforced
- Audit cluster usage patterns

## Migration Guide

If you have existing clusters without policies:

1. Create policies with permissive settings
2. Document existing cluster configurations
3. Gradually tighten policy constraints
4. Communicate changes to users
5. Enforce policies on new clusters

## References

- [Databricks Cluster Policies](https://docs.databricks.com/en/administration-guide/clusters/policies.html)
- [Policy Definition Reference](https://docs.databricks.com/en/administration-guide/clusters/policy-definition.html)
- [Cost Management](https://docs.databricks.com/en/administration-guide/account-settings/usage.html)
