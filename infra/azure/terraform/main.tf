# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------

locals {
  name_prefix = "${var.company_prefix}-shared"

  common_tags = {
    Project     = "shared-infrastructure"
    Environment = var.environment
    ManagedBy   = "terraform"
    Company     = var.company_prefix
  }
}

data "azurerm_client_config" "current" {}

# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "main" {
  name     = "${local.name_prefix}-rg-${var.environment}"
  location = var.azure_location

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# VNet
# -----------------------------------------------------------------------------

resource "azurerm_virtual_network" "main" {
  count = var.create_vnet ? 1 : 0

  name                = "${local.name_prefix}-vnet-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.vnet_cidr]

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Subnets
# -----------------------------------------------------------------------------

resource "azurerm_subnet" "public" {
  count = var.create_vnet ? 1 : 0

  name                 = "${local.name_prefix}-public-${var.environment}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = [var.public_subnet_cidr]
}

resource "azurerm_subnet" "private" {
  count = var.create_vnet ? 1 : 0

  name                 = "${local.name_prefix}-private-${var.environment}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = [var.private_subnet_cidr]

  delegation {
    name = "postgresql-delegation"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_subnet" "container_apps" {
  count = var.create_vnet && var.create_container_apps_environment ? 1 : 0

  name                 = "${local.name_prefix}-container-apps-${var.environment}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = [var.container_apps_subnet_cidr]

  delegation {
    name = "container-apps-delegation"

    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# -----------------------------------------------------------------------------
# NAT Gateway
# -----------------------------------------------------------------------------

resource "azurerm_public_ip" "nat" {
  count = var.create_vnet && var.enable_nat_gateway ? 1 : 0

  name                = "${local.name_prefix}-nat-pip-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.common_tags
}

resource "azurerm_nat_gateway" "main" {
  count = var.create_vnet && var.enable_nat_gateway ? 1 : 0

  name                = "${local.name_prefix}-nat-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  count = var.create_vnet && var.enable_nat_gateway ? 1 : 0

  nat_gateway_id       = azurerm_nat_gateway.main[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "private" {
  count = var.create_vnet && var.enable_nat_gateway ? 1 : 0

  subnet_id      = azurerm_subnet.private[0].id
  nat_gateway_id = azurerm_nat_gateway.main[0].id
}

# -----------------------------------------------------------------------------
# Container Apps Environment + Log Analytics
# -----------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "main" {
  count = var.create_container_apps_environment ? 1 : 0

  name                = "${local.name_prefix}-logs-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.common_tags
}

resource "azurerm_container_app_environment" "main" {
  count = var.create_container_apps_environment ? 1 : 0

  name                       = "${local.name_prefix}-cae-${var.environment}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id

  infrastructure_subnet_id = var.create_vnet ? azurerm_subnet.container_apps[0].id : null

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Private DNS Zone for PostgreSQL
# -----------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "postgresql" {
  count = var.create_vnet && var.create_postgresql ? 1 : 0

  name                = "${local.name_prefix}-${var.environment}.private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  count = var.create_vnet && var.create_postgresql ? 1 : 0

  name                  = "${local.name_prefix}-pg-vnet-link-${var.environment}"
  private_dns_zone_name = azurerm_private_dns_zone.postgresql[0].name
  resource_group_name   = azurerm_resource_group.main.name
  virtual_network_id    = azurerm_virtual_network.main[0].id
}

# -----------------------------------------------------------------------------
# PostgreSQL Flexible Server
# -----------------------------------------------------------------------------

resource "random_password" "postgresql_master" {
  count = var.create_postgresql ? 1 : 0

  length  = 32
  special = false
}

resource "azurerm_postgresql_flexible_server" "main" {
  count = var.create_postgresql ? 1 : 0

  name                = "${local.name_prefix}-pg-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  version                       = var.postgresql_version
  sku_name                      = var.postgresql_sku
  storage_mb                    = var.postgresql_storage_mb
  administrator_login           = var.postgresql_admin_username
  administrator_password        = random_password.postgresql_master[0].result
  delegated_subnet_id           = var.create_vnet ? azurerm_subnet.private[0].id : null
  private_dns_zone_id           = var.create_vnet ? azurerm_private_dns_zone.postgresql[0].id : null
  geo_redundant_backup_enabled  = var.postgresql_geo_redundant_backup
  auto_grow_enabled             = true

  high_availability {
    mode = var.postgresql_ha ? "ZoneRedundant" : "Disabled"
  }

  maintenance_window {
    day_of_week  = 1
    start_hour   = 4
    start_minute = 0
  }

  tags = local.common_tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgresql]
}

resource "azurerm_postgresql_flexible_server_database" "main" {
  count = var.create_postgresql ? 1 : 0

  name      = var.postgresql_database_name
  server_id = azurerm_postgresql_flexible_server.main[0].id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# -----------------------------------------------------------------------------
# Key Vault (secrets + encryption keys + DB password)
# -----------------------------------------------------------------------------

resource "azurerm_key_vault" "main" {
  name                       = substr("${var.company_prefix}-shared-kv-${var.environment}", 0, 24)
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false # Set to true for production

  # Allow the current user/SP to manage secrets and keys
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge",
    ]

    key_permissions = [
      "Get", "List", "Create", "Delete", "Purge",
      "Encrypt", "Decrypt", "WrapKey", "UnwrapKey",
    ]
  }

  tags = local.common_tags
}

resource "azurerm_key_vault_secret" "postgresql_master_password" {
  count = var.create_postgresql ? 1 : 0

  name         = "${local.name_prefix}-pg-master-password-${var.environment}"
  value        = random_password.postgresql_master[0].result
  key_vault_id = azurerm_key_vault.main.id
}
