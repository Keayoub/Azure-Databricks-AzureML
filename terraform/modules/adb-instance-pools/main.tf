# ========================================
# Databricks Instance Pools Module
# ========================================
# Purpose: Create and manage instance pools for faster cluster startup
# Benefits: Reduced startup time, cost savings, resource pre-allocation

terraform {
  required_version = ">= 1.0"
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.0"
    }
  }
}

# ========== Data Sources ==========
data "databricks_node_type" "default_node_type" {
  local_disk    = true
  min_cores     = var.default_min_cores
  min_memory_gb = var.default_min_memory_gb
}

# ========== Instance Pools ==========

# General Purpose Pool
resource "databricks_instance_pool" "general_purpose" {
  count = var.create_general_purpose_pool ? 1 : 0

  instance_pool_name = "${var.environment_name}-general-purpose-pool"
  
  min_idle_instances = var.general_purpose_min_idle
  max_capacity       = var.general_purpose_max_capacity
  
  node_type_id = var.general_purpose_node_type != "" ? var.general_purpose_node_type : data.databricks_node_type.default_node_type.id
  
  idle_instance_autotermination_minutes = var.idle_instance_autotermination_minutes

  preloaded_spark_versions = [
    var.default_spark_version
  ]

  azure_attributes {
    availability       = var.azure_availability
    spot_bid_max_price = var.enable_spot_instances ? var.spot_bid_max_price : -1
  }

  custom_tags = merge(
    var.tags,
    {
      PoolType    = "GeneralPurpose"
      Environment = var.environment_name
    }
  )

  enable_elastic_disk = var.enable_elastic_disk
}

# High Memory Pool - For memory-intensive workloads
resource "databricks_instance_pool" "high_memory" {
  count = var.create_high_memory_pool ? 1 : 0

  instance_pool_name = "${var.environment_name}-high-memory-pool"
  
  min_idle_instances = var.high_memory_min_idle
  max_capacity       = var.high_memory_max_capacity
  
  node_type_id = var.high_memory_node_type != "" ? var.high_memory_node_type : "Standard_E8s_v3"
  
  idle_instance_autotermination_minutes = var.idle_instance_autotermination_minutes

  preloaded_spark_versions = [
    var.default_spark_version
  ]

  azure_attributes {
    availability       = var.azure_availability
    spot_bid_max_price = -1 # On-demand only for high-memory
  }

  custom_tags = merge(
    var.tags,
    {
      PoolType    = "HighMemory"
      Environment = var.environment_name
    }
  )

  enable_elastic_disk = var.enable_elastic_disk
}

# Compute Optimized Pool - For compute-intensive workloads
resource "databricks_instance_pool" "compute_optimized" {
  count = var.create_compute_optimized_pool ? 1 : 0

  instance_pool_name = "${var.environment_name}-compute-optimized-pool"
  
  min_idle_instances = var.compute_optimized_min_idle
  max_capacity       = var.compute_optimized_max_capacity
  
  node_type_id = var.compute_optimized_node_type != "" ? var.compute_optimized_node_type : "Standard_F8s_v2"
  
  idle_instance_autotermination_minutes = var.idle_instance_autotermination_minutes

  preloaded_spark_versions = [
    var.default_spark_version
  ]

  azure_attributes {
    availability       = var.azure_availability
    spot_bid_max_price = var.enable_spot_instances ? var.spot_bid_max_price : -1
  }

  custom_tags = merge(
    var.tags,
    {
      PoolType    = "ComputeOptimized"
      Environment = var.environment_name
    }
  )

  enable_elastic_disk = var.enable_elastic_disk
}

# GPU Pool - For ML training
resource "databricks_instance_pool" "gpu" {
  count = var.create_gpu_pool ? 1 : 0

  instance_pool_name = "${var.environment_name}-gpu-pool"
  
  min_idle_instances = var.gpu_min_idle
  max_capacity       = var.gpu_max_capacity
  
  node_type_id = var.gpu_node_type != "" ? var.gpu_node_type : "Standard_NC6s_v3"
  
  idle_instance_autotermination_minutes = var.idle_instance_autotermination_minutes

  preloaded_spark_versions = [
    var.gpu_spark_version != "" ? var.gpu_spark_version : var.default_spark_version
  ]

  azure_attributes {
    availability       = "ON_DEMAND_AZURE" # GPUs typically on-demand only
    spot_bid_max_price = -1
  }

  custom_tags = merge(
    var.tags,
    {
      PoolType    = "GPU"
      Environment = var.environment_name
      Workload    = "MLTraining"
    }
  )

  enable_elastic_disk = var.enable_elastic_disk
}

# Custom Instance Pools
resource "databricks_instance_pool" "custom_pools" {
  for_each = var.custom_pools

  instance_pool_name = each.key
  
  min_idle_instances = each.value.min_idle_instances
  max_capacity       = each.value.max_capacity
  
  node_type_id = each.value.node_type_id
  
  idle_instance_autotermination_minutes = each.value.idle_instance_autotermination_minutes

  preloaded_spark_versions = each.value.preloaded_spark_versions

  azure_attributes {
    availability       = each.value.azure_availability
    spot_bid_max_price = each.value.spot_bid_max_price
  }

  custom_tags = merge(
    var.tags,
    each.value.custom_tags,
    {
      Environment = var.environment_name
    }
  )

  enable_elastic_disk = each.value.enable_elastic_disk
}

# ========== Instance Pool Permissions ==========
resource "databricks_permissions" "general_purpose_pool" {
  count = var.create_general_purpose_pool ? 1 : 0

  instance_pool_id = databricks_instance_pool.general_purpose[0].id

  dynamic "access_control" {
    for_each = var.general_purpose_pool_permissions
    content {
      group_name       = access_control.value.group_name
      permission_level = access_control.value.permission_level
    }
  }
}

resource "databricks_permissions" "high_memory_pool" {
  count = var.create_high_memory_pool ? 1 : 0

  instance_pool_id = databricks_instance_pool.high_memory[0].id

  dynamic "access_control" {
    for_each = var.high_memory_pool_permissions
    content {
      group_name       = access_control.value.group_name
      permission_level = access_control.value.permission_level
    }
  }
}

resource "databricks_permissions" "gpu_pool" {
  count = var.create_gpu_pool ? 1 : 0

  instance_pool_id = databricks_instance_pool.gpu[0].id

  dynamic "access_control" {
    for_each = var.gpu_pool_permissions
    content {
      group_name       = access_control.value.group_name
      permission_level = access_control.value.permission_level
    }
  }
}
