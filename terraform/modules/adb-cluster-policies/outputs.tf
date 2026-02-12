output "personal_compute_policy_id" {
  description = "Personal compute policy ID"
  value       = var.create_personal_compute_policy ? databricks_cluster_policy.personal_compute[0].id : null
}

output "shared_compute_policy_id" {
  description = "Shared compute policy ID"
  value       = var.create_shared_compute_policy ? databricks_cluster_policy.shared_compute[0].id : null
}

output "production_jobs_policy_id" {
  description = "Production jobs policy ID"
  value       = var.create_production_jobs_policy ? databricks_cluster_policy.production_jobs[0].id : null
}

output "high_concurrency_policy_id" {
  description = "High concurrency policy ID"
  value       = var.create_high_concurrency_policy ? databricks_cluster_policy.high_concurrency[0].id : null
}

output "custom_policy_ids" {
  description = "Custom policy IDs"
  value       = { for k, v in databricks_cluster_policy.custom_policies : k => v.id }
}

output "all_policy_ids" {
  description = "All cluster policy IDs"
  value = merge(
    var.create_personal_compute_policy ? { personal_compute = databricks_cluster_policy.personal_compute[0].id } : {},
    var.create_shared_compute_policy ? { shared_compute = databricks_cluster_policy.shared_compute[0].id } : {},
    var.create_production_jobs_policy ? { production_jobs = databricks_cluster_policy.production_jobs[0].id } : {},
    var.create_high_concurrency_policy ? { high_concurrency = databricks_cluster_policy.high_concurrency[0].id } : {},
    { for k, v in databricks_cluster_policy.custom_policies : k => v.id }
  )
}
