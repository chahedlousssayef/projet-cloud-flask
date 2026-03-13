output "vm_public_ip" {
  description = "IP publique de la VM"
  value       = azurerm_linux_virtual_machine.vm.public_ip_address
}

output "frontend_url" {
  description = "URL du frontend (Image Clock)"
  value       = "http://${azurerm_linux_virtual_machine.vm.public_ip_address}"
}

output "api_url" {
  description = "URL de l'API Flask"
  value       = "http://${azurerm_linux_virtual_machine.vm.public_ip_address}:${var.flask_port}"
}

output "ssh_command" {
  description = "Commande SSH pour se connecter à la VM"
  value       = "ssh ${var.admin_username}@${azurerm_linux_virtual_machine.vm.public_ip_address}"
}

output "storage_account_name" {
  description = "Nom du storage account Azure Blob"
  value       = azurerm_storage_account.storage.name
}

output "storage_container_name" {
  description = "Nom du conteneur Blob"
  value       = azurerm_storage_container.container.name
}

output "resource_group_name" {
  description = "Nom du resource group"
  value       = azurerm_resource_group.rg.name
}
