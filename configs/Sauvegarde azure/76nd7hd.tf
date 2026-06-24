output "storage_account_name" {
  description = "À reporter dans backup-ad.ps1 (paramètre -StorageAccount)"
  value       = azurerm_storage_account.backup.name
}

output "resource_group_name" {
  value = azurerm_resource_group.backup.name
}

output "container_name" {
  value = azurerm_storage_container.backup.name
}

output "blob_endpoint" {
  value = azurerm_storage_account.backup.primary_blob_endpoint
}
