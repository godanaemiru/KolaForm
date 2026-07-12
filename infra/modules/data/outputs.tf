output "storage_account_id" {
  value = azurerm_storage_account.data.id
}

output "storage_account_name" {
  value = azurerm_storage_account.data.name
}

output "container_name" {
  value = azurerm_storage_container.data.name
}
