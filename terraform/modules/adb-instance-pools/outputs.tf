output "general_purpose_pool_id" {
  description = "General purpose pool ID"
  value       = var.create_general_purpose_pool ? databricks_instance_pool.general_purpose[0].id : null
}

output "high_memory_pool_id" {
  description = "High memory pool ID"
  value       = var.create_high_memory_pool ? databricks_instance_pool.high_memory[0].id : null
}

output "compute_optimized_pool_id" {
  description = "Compute optimized pool ID"
  value       = var.create_compute_optimized_pool ? databricks_instance_pool.compute_optimized[0].id : null
}

output "gpu_pool_id" {
  description = "GPU pool ID"
  value       = var.create_gpu_pool ? databricks_instance_pool.gpu[0].id : null
}

output "custom_pool_ids" {
  description = "Custom pool IDs"
  value       = { for k, v in databricks_instance_pool.custom_pools : k => v.id }
}

output "all_pool_ids" {
  description = "All instance pool IDs"
  value = merge(
    var.create_general_purpose_pool ? { general_purpose = databricks_instance_pool.general_purpose[0].id } : {},
    var.create_high_memory_pool ? { high_memory = databricks_instance_pool.high_memory[0].id } : {},
    var.create_compute_optimized_pool ? { compute_optimized = databricks_instance_pool.compute_optimized[0].id } : {},
    var.create_gpu_pool ? { gpu = databricks_instance_pool.gpu[0].id } : {},
    { for k, v in databricks_instance_pool.custom_pools : k => v.id }
  )
}
