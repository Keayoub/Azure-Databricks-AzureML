# Databricks Instance Pools Module

## Overview

Instance pools reduce cluster startup time by maintaining a pool of idle, ready-to-use instances. This module creates and manages instance pools for different workload types.

## Benefits

- **Faster Startup**: Clusters start in seconds instead of minutes
- **Cost Savings**: Up to 50% savings on Azure spot instances
- **Resource Management**: Pre-allocated capacity for critical workloads
- **Predictable Performance**: Guaranteed resources for production jobs

## Pre-built Pools

### 1. General Purpose Pool
- **Use Case**: Development, exploratory analysis
- **Default Node**: Standard_DS3_v2 (4 cores, 14 GB)
- **Capacity**: 0-10 instances
- **Availability**: Configurable (on-demand/spot)

### 2. High Memory Pool
- **Use Case**: Large datasets, memory-intensive operations
- **Default Node**: Standard_E8s_v3 (8 cores, 64 GB)
- **Capacity**: 0-5 instances
- **Availability**: On-demand only

### 3. Compute Optimized Pool
- **Use Case**: CPU-intensive workloads, ETL
- **Default Node**: Standard_F8s_v2 (8 cores, 16 GB)
- **Capacity**: 0-8 instances
- **Availability**: Configurable

### 4. GPU Pool
- **Use Case**: ML training, deep learning
- **Default Node**: Standard_NC6s_v3 (6 cores, 112 GB, 1 GPU)
- **Capacity**: 0-3 instances
- **Availability**: On-demand only

## Usage

### Basic Configuration

```hcl
module "instance_pools" {
  source = "../modules/adb-instance-pools"

  environment_name = "prod"

  # Enable pools
  create_general_purpose_pool    = true
  create_high_memory_pool        = true
  create_gpu_pool                = true

  # General purpose settings
  general_purpose_min_idle       = 2
  general_purpose_max_capacity   = 10

  # Cost optimization
  enable_spot_instances          = true
  azure_availability             = "SPOT_WITH_FALLBACK_AZURE"
  idle_instance_autotermination_minutes = 15

  # Permissions
  general_purpose_pool_permissions = [
    {
      group_name       = "data-scientists"
      permission_level = "CAN_ATTACH_TO"
    }
  ]

  tags = {
    ManagedBy = "Terraform"
    CostCenter = "DataPlatform"
  }
}
```

### Custom Pool Example

```hcl
custom_pools = {
  "streaming-pool" = {
    min_idle_instances                    = 1
    max_capacity                          = 5
    node_type_id                          = "Standard_D8s_v3"
    idle_instance_autotermination_minutes = 30
    preloaded_spark_versions              = ["13.3.x-scala2.12"]
    azure_availability                    = "ON_DEMAND_AZURE"
    spot_bid_max_price                    = -1
    enable_elastic_disk                   = true
    custom_tags = {
      Workload = "Streaming"
    }
  }
}
```

## Cost Optimization Strategies

### Spot Instances
```hcl
enable_spot_instances = true
azure_availability    = "SPOT_WITH_FALLBACK_AZURE"
spot_bid_max_price    = -1  # Match on-demand price
```

**Savings**: 60-80% compared to on-demand
**Risk**: Can be evicted with 30-second notice
**Best For**: Development, fault-tolerant production jobs

### Right-Sizing
```hcl
# Development
general_purpose_min_idle = 0
general_purpose_max_capacity = 5

# Production
general_purpose_min_idle = 2
general_purpose_max_capacity = 20
```

### Idle Termination
```hcl
idle_instance_autotermination_minutes = 15  # Dev: 10-15 min
idle_instance_autotermination_minutes = 30  # Prod: 30-60 min
```

## Pool Selection Guide

| Workload | Pool | Reason |
|----------|------|--------|
| Notebooks | General Purpose | Balanced resources |
| ETL Jobs | Compute Optimized | High CPU throughput |
| Large Joins | High Memory | Avoid OOM errors |
| ML Training | GPU | Accelerated compute |
| Streaming | Custom | Steady-state resources |

## Variables

| Name | Description | Default | Required |
|------|-------------|---------|----------|
| `environment_name` | Environment (dev/staging/prod) | - | Yes |
| `create_general_purpose_pool` | Create general purpose pool | `true` | No |
| `general_purpose_min_idle` | Min idle instances | `0` | No |
| `general_purpose_max_capacity` | Max pool capacity | `10` | No |
| `enable_spot_instances` | Use spot instances | `false` | No |
| `idle_instance_autotermination_minutes` | Idle timeout | `15` | No |

## Outputs

| Name | Description |
|------|-------------|
| `general_purpose_pool_id` | General purpose pool ID |
| `high_memory_pool_id` | High memory pool ID |
| `gpu_pool_id` | GPU pool ID |
| `all_pool_ids` | Map of all pool IDs |

## Best Practices

### Development Environments
- Min idle: 0 (no pre-warmed instances)
- Max capacity: 5-10
- Use spot instances aggressively
- Short idle termination (10-15 min)

### Production Environments
- Min idle: 2-5 (guaranteed capacity)
- Max capacity: Based on peak load
- Mix of spot and on-demand
- Longer idle termination (30-60 min)

### GPU Pools
- Min idle: 0 (expensive to keep idle)
- On-demand only (spot GPUs rare/unreliable)
- Short idle termination (5-10 min)
- Strict permissions (ML team only)

## Monitoring

Track these metrics:

- **Pool Utilization**: Idle vs active instances
- **Startup Time**: With vs without pools
- **Cost**: Compare to non-pool deployments
- **Eviction Rate**: Spot instance stability

## Troubleshooting

### Slow Cluster Startup Despite Pools

**Cause**: Pool exhausted or wrong Spark version
**Solution**: 
- Increase max_capacity
- Verify Spark version matches
- Check pool availability in workspace UI

### High Costs

**Cause**: Too many idle instances
**Solution**:
- Reduce min_idle
- Lower idle_instance_autotermination_minutes
- Review actual usage patterns

### Spot Evictions

**Cause**: High demand for VM type in region
**Solution**:
- Use SPOT_WITH_FALLBACK_AZURE
- Choose less popular VM sizes
- Consider on-demand for critical jobs

## Advanced Configuration

### Multi-Region Pools
Not directly supported. Deploy separate modules per region.

### Pool Sharing
Pools are workspace-scoped. Use permissions to control access.

### Preload Multiple Spark Versions
```hcl
preloaded_spark_versions = [
  "13.3.x-scala2.12",
  "12.2.x-scala2.12"
]
```

## Migration from Manual Pools

1. Document existing pool configurations
2. Import existing pools:
   ```bash
   terraform import databricks_instance_pool.general_purpose[0] <pool-id>
   ```
3. Update Terraform state
4. Apply changes gradually

## References

- [Databricks Instance Pools](https://docs.databricks.com/en/compute/pool-index.html)
- [Azure Spot VMs](https://learn.microsoft.com/azure/virtual-machines/spot-vms)
- [Pool Best Practices](https://docs.databricks.com/en/compute/pool-best-practices.html)
