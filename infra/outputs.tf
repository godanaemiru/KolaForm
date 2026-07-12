output "resource_group" {
  description = "Resource group holding all infrastructure."
  value       = azurerm_resource_group.main.name
}

output "storage_account" {
  description = "ADLS Gen2 storage account (the data layer)."
  value       = module.data.storage_account_name
}

output "data_container" {
  description = "Blob container the compute layer writes heartbeats into."
  value       = module.data.container_name
}

output "container_group" {
  description = "Container instance (the compute layer)."
  value       = module.compute.container_group_name
}

output "compute_subnet_id" {
  description = "Private subnet the compute layer runs in."
  value       = module.network.compute_subnet_id
}
