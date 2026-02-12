# ========================================
# Databricks Cluster Policies Module
# ========================================
# Purpose: Define and enforce cluster policies for cost control and security
# Scope: Workspace-level cluster policies
# Benefits: Cost optimization, security hardening, compliance

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
data "databricks_current_user" "me" {}

data "databricks_node_type" "smallest" {
  local_disk = true
  min_cores  = 4
  min_memory_gb = 16
}

data "databricks_spark_version" "latest_lts" {
  long_term_support = true
}

# ========== Local Variables ==========
locals {
  # Base policies that can be merged with custom policies
  base_cost_policy = {
    "autoscale.min_workers" = {
      type  = "range"
      maxValue = 2
      defaultValue = 1
    }
    "autoscale.max_workers" = {
      type  = "range"
      maxValue = var.max_workers_limit
      defaultValue = 4
    }
    "autotermination_minutes" = {
      type  = "fixed"
      value = var.auto_termination_minutes
    }
    "spark_conf.spark.databricks.cluster.profile" = {
      type  = "fixed"
      value = "serverless"
    }
  }

  base_security_policy = {
    "enable_elastic_disk" = {
      type  = "fixed"
      value = true
    }
    "cluster_type" = {
      type  = "fixed"
      value = "all-purpose"
    }
    "data_security_mode" = {
      type  = "fixed"
      value = "USER_ISOLATION"
    }
  }

  # Merge custom policies with baseline
  merged_policies = merge(
    var.enable_cost_controls ? local.base_cost_policy : {},
    var.enable_security_hardening ? local.base_security_policy : {},
    var.additional_policy_rules
  )
}

# ========== Cluster Policies ==========

# Personal Compute Policy - For individual data scientists
resource "databricks_cluster_policy" "personal_compute" {
  count = var.create_personal_compute_policy ? 1 : 0

  name = "${var.environment_name}-personal-compute"
  
  definition = jsonencode({
    "spark_version" = {
      type  = "unlimited"
      defaultValue = data.databricks_spark_version.latest_lts.id
    }
    "node_type_id" = {
      type  = "allowlist"
      values = var.allowed_node_types
      defaultValue = data.databricks_node_type.smallest.id
    }
    "autoscale.min_workers" = {
      type  = "range"
      maxValue = 2
      minValue = 0
      defaultValue = 0
    }
    "autoscale.max_workers" = {
      type  = "range"
      maxValue = 4
      minValue = 1
      defaultValue = 2
    }
    "autotermination_minutes" = {
      type  = "fixed"
      value = 30
      hidden = false
    }
    "custom_tags.Environment" = {
      type  = "fixed"
      value = var.environment_name
    }
    "custom_tags.PolicyType" = {
      type  = "fixed"
      value = "PersonalCompute"
    }
  })

  description = "Policy for personal development and exploration"
}

# Shared Compute Policy - For team collaboration
resource "databricks_cluster_policy" "shared_compute" {
  count = var.create_shared_compute_policy ? 1 : 0

  name = "${var.environment_name}-shared-compute"
  
  definition = jsonencode({
    "spark_version" = {
      type  = "unlimited"
      defaultValue = data.databricks_spark_version.latest_lts.id
    }
    "node_type_id" = {
      type  = "allowlist"
      values = var.allowed_node_types
      defaultValue = data.databricks_node_type.smallest.id
    }
    "num_workers" = {
      type  = "range"
      maxValue = 10
      minValue = 2
      defaultValue = 4
    }
    "autotermination_minutes" = {
      type  = "fixed"
      value = 60
      hidden = false
    }
    "data_security_mode" = {
      type  = "fixed"
      value = "USER_ISOLATION"
    }
    "custom_tags.Environment" = {
      type  = "fixed"
      value = var.environment_name
    }
    "custom_tags.PolicyType" = {
      type  = "fixed"
      value = "SharedCompute"
    }
  })

  description = "Policy for shared team clusters"
}

# Production Jobs Policy - For production workloads
resource "databricks_cluster_policy" "production_jobs" {
  count = var.create_production_jobs_policy ? 1 : 0

  name = "${var.environment_name}-production-jobs"
  
  definition = jsonencode({
    "spark_version" = {
      type  = "unlimited"
      defaultValue = data.databricks_spark_version.latest_lts.id
    }
    "node_type_id" = {
      type  = "allowlist"
      values = var.allowed_node_types
    }
    "autoscale.min_workers" = {
      type  = "range"
      maxValue = 20
      minValue = 2
      defaultValue = 2
    }
    "autoscale.max_workers" = {
      type  = "range"
      maxValue = 50
      minValue = 2
      defaultValue = 10
    }
    "autotermination_minutes" = {
      type  = "fixed"
      value = 10
      hidden = true
    }
    "cluster_type" = {
      type  = "fixed"
      value = "job"
    }
    "data_security_mode" = {
      type  = "fixed"
      value = "USER_ISOLATION"
    }
    "spark_conf.spark.databricks.delta.preview.enabled" = {
      type  = "fixed"
      value = "true"
    }
    "custom_tags.Environment" = {
      type  = "fixed"
      value = var.environment_name
    }
    "custom_tags.PolicyType" = {
      type  = "fixed"
      value = "ProductionJobs"
    }
    "custom_tags.CostCenter" = {
      type  = "unlimited"
      defaultValue = var.default_cost_center
    }
  })

  description = "Policy for production ETL and batch jobs"
}

# High Concurrency Policy - For SQL Analytics
resource "databricks_cluster_policy" "high_concurrency" {
  count = var.create_high_concurrency_policy ? 1 : 0

  name = "${var.environment_name}-high-concurrency"
  
  definition = jsonencode({
    "spark_version" = {
      type  = "unlimited"
      defaultValue = data.databricks_spark_version.latest_lts.id
    }
    "node_type_id" = {
      type  = "allowlist"
      values = var.allowed_node_types
    }
    "num_workers" = {
      type  = "range"
      maxValue = 20
      minValue = 1
      defaultValue = 4
    }
    "autotermination_minutes" = {
      type  = "fixed"
      value = 120
    }
    "data_security_mode" = {
      type  = "fixed"
      value = "USER_ISOLATION"
    }
    "spark_conf.spark.databricks.repl.allowedLanguages" = {
      type  = "fixed"
      value = "sql,python,r"
    }
    "custom_tags.Environment" = {
      type  = "fixed"
      value = var.environment_name
    }
    "custom_tags.PolicyType" = {
      type  = "fixed"
      value = "HighConcurrency"
    }
  })

  description = "Policy for high-concurrency SQL analytics"
}

# Custom Policies (user-defined)
resource "databricks_cluster_policy" "custom_policies" {
  for_each = var.custom_policies

  name       = each.key
  definition = jsonencode(each.value.definition)
  description = each.value.description
}

# ========== Policy Permissions ==========
resource "databricks_permissions" "personal_compute_policy" {
  count = var.create_personal_compute_policy ? 1 : 0

  cluster_policy_id = databricks_cluster_policy.personal_compute[0].id

  dynamic "access_control" {
    for_each = var.personal_compute_permissions
    content {
      group_name       = access_control.value.group_name
      permission_level = access_control.value.permission_level
    }
  }
}

resource "databricks_permissions" "shared_compute_policy" {
  count = var.create_shared_compute_policy ? 1 : 0

  cluster_policy_id = databricks_cluster_policy.shared_compute[0].id

  dynamic "access_control" {
    for_each = var.shared_compute_permissions
    content {
      group_name       = access_control.value.group_name
      permission_level = access_control.value.permission_level
    }
  }
}

resource "databricks_permissions" "production_jobs_policy" {
  count = var.create_production_jobs_policy ? 1 : 0

  cluster_policy_id = databricks_cluster_policy.production_jobs[0].id

  dynamic "access_control" {
    for_each = var.production_jobs_permissions
    content {
      group_name       = access_control.value.group_name
      permission_level = access_control.value.permission_level
    }
  }
}
