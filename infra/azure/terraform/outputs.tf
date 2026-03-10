# -----------------------------------------------------------------------------
# Resource Group Outputs
# -----------------------------------------------------------------------------

output "resource_group_name" {
  description = "Name of the shared resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the shared resource group"
  value       = azurerm_resource_group.main.location
}

# -----------------------------------------------------------------------------
# VNet Outputs
# -----------------------------------------------------------------------------

output "vnet_id" {
  description = "ID of the VNet"
  value       = var.create_vnet ? azurerm_virtual_network.main[0].id : ""
}

output "vnet_name" {
  description = "Name of the VNet"
  value       = var.create_vnet ? azurerm_virtual_network.main[0].name : ""
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = var.create_vnet ? azurerm_subnet.public[0].id : ""
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = var.create_vnet ? azurerm_subnet.private[0].id : ""
}

output "container_apps_subnet_id" {
  description = "ID of the Container Apps subnet"
  value       = var.create_vnet && var.create_container_apps_environment ? azurerm_subnet.container_apps[0].id : ""
}

# -----------------------------------------------------------------------------
# Container Apps Environment Outputs
# -----------------------------------------------------------------------------

output "container_apps_environment_id" {
  description = "ID of the Container Apps Environment"
  value       = var.create_container_apps_environment ? azurerm_container_app_environment.main[0].id : ""
}

output "container_apps_environment_name" {
  description = "Name of the Container Apps Environment"
  value       = var.create_container_apps_environment ? azurerm_container_app_environment.main[0].name : ""
}

# -----------------------------------------------------------------------------
# PostgreSQL Outputs
# -----------------------------------------------------------------------------

output "postgresql_fqdn" {
  description = "FQDN of the PostgreSQL Flexible Server"
  value       = var.create_postgresql ? azurerm_postgresql_flexible_server.main[0].fqdn : ""
}

output "postgresql_id" {
  description = "ID of the PostgreSQL Flexible Server"
  value       = var.create_postgresql ? azurerm_postgresql_flexible_server.main[0].id : ""
}

output "postgresql_database_name" {
  description = "Name of the default database"
  value       = var.create_postgresql ? azurerm_postgresql_flexible_server_database.main[0].name : ""
}

# -----------------------------------------------------------------------------
# Key Vault Outputs
# -----------------------------------------------------------------------------

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "postgresql_password_secret_id" {
  description = "Key Vault secret ID for PostgreSQL master password"
  value       = var.create_postgresql ? azurerm_key_vault_secret.postgresql_master_password[0].id : ""
}

# -----------------------------------------------------------------------------
# Summary Output
# -----------------------------------------------------------------------------

output "shared_infrastructure_summary" {
  description = "Summary of shared infrastructure for use by application projects"
  value = {
    resource_group_name           = azurerm_resource_group.main.name
    vnet_id                       = var.create_vnet ? azurerm_virtual_network.main[0].id : ""
    container_apps_environment_id = var.create_container_apps_environment ? azurerm_container_app_environment.main[0].id : ""
    postgresql_fqdn               = var.create_postgresql ? azurerm_postgresql_flexible_server.main[0].fqdn : ""
    key_vault_id                  = azurerm_key_vault.main.id
    key_vault_uri                 = azurerm_key_vault.main.vault_uri
    postgresql_password_secret_id = var.create_postgresql ? azurerm_key_vault_secret.postgresql_master_password[0].id : ""
  }
}
