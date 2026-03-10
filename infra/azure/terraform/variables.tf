# -----------------------------------------------------------------------------
# General Configuration
# -----------------------------------------------------------------------------

variable "company_prefix" {
  description = "Company prefix for resource naming (e.g., mycompany, acme)"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "azure_location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

# -----------------------------------------------------------------------------
# VNet Configuration
# -----------------------------------------------------------------------------

variable "create_vnet" {
  description = "Whether to create a new VNet"
  type        = bool
  default     = true
}

variable "vnet_cidr" {
  description = "Address space for the VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR for the private subnet (PostgreSQL delegation)"
  type        = string
  default     = "10.0.10.0/24"
}

variable "container_apps_subnet_cidr" {
  description = "CIDR for the Container Apps subnet (minimum /23)"
  type        = string
  default     = "10.0.16.0/23"
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnet"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# PostgreSQL Flexible Server Configuration
# -----------------------------------------------------------------------------

variable "create_postgresql" {
  description = "Whether to create a new PostgreSQL Flexible Server"
  type        = bool
  default     = true
}

variable "postgresql_sku" {
  description = "PostgreSQL Flexible Server SKU"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgresql_storage_mb" {
  description = "PostgreSQL storage in MB"
  type        = number
  default     = 32768
}

variable "postgresql_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15"
}

variable "postgresql_database_name" {
  description = "Name of the default database"
  type        = string
  default     = "appdb"
}

variable "postgresql_admin_username" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "postgres"
}

variable "postgresql_ha" {
  description = "Enable high availability for PostgreSQL"
  type        = bool
  default     = false
}

variable "postgresql_geo_redundant_backup" {
  description = "Enable geo-redundant backups"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Container Apps Configuration
# -----------------------------------------------------------------------------

variable "create_container_apps_environment" {
  description = "Whether to create a Container Apps Environment"
  type        = bool
  default     = true
}
