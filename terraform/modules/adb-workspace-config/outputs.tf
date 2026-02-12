output "workspace_configured" {
  description = "Indicates if workspace configuration was applied"
  value       = var.enable_workspace_config
}

output "ip_access_lists" {
  description = "IP access lists created"
  value       = { for k, v in databricks_ip_access_list.allowed_ips : k => v.id }
}

output "admin_groups" {
  description = "Admin groups created"
  value       = { for k, v in databricks_group.admin_groups : k => v.display_name }
}

output "global_init_scripts" {
  description = "Global init scripts created"
  value       = { for k, v in databricks_global_init_script.init_scripts : k => v.name }
}
