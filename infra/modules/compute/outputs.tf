output "container_group_name" {
  value = azurerm_container_group.worker.name
}

output "worker_identity_client_id" {
  value = azurerm_user_assigned_identity.worker.client_id
}
