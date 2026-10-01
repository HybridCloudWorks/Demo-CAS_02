output "resource_group_name" {
  description = "Demo resource group (target for azcmagent connect --resource-group)."
  value       = azurerm_resource_group.demo.name
}

output "location" {
  description = "Azure region for Arc metadata."
  value       = azurerm_resource_group.demo.location
}

output "log_analytics_workspace_id" {
  description = "Workspace resource ID."
  value       = azurerm_log_analytics_workspace.demo.id
}

output "log_analytics_customer_id" {
  description = "Workspace (customer) GUID used by az monitor log-analytics query."
  value       = azurerm_log_analytics_workspace.demo.workspace_id
  sensitive   = true
}

output "data_collection_rule_id" {
  description = "DCR resource ID associated with Arc Linux machines."
  value       = azurerm_monitor_data_collection_rule.arc_linux.id
}

output "foundry_endpoint" {
  description = "Optional Foundry endpoint (empty when deploy_foundry=false)."
  value       = var.deploy_foundry ? azurerm_cognitive_account.foundry[0].endpoint : ""
  sensitive   = true
}
