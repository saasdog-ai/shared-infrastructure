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

variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
  default     = "us-east1"
}

# -----------------------------------------------------------------------------
# VPC Configuration
# -----------------------------------------------------------------------------

variable "create_vpc" {
  description = "Whether to create a new VPC network"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "Primary CIDR range for the VPC subnet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR range for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR range for the private subnet"
  type        = string
  default     = "10.0.10.0/24"
}

variable "enable_nat" {
  description = "Enable Cloud NAT for private subnet internet access"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Cloud SQL Configuration
# -----------------------------------------------------------------------------

variable "create_cloud_sql" {
  description = "Whether to create a new Cloud SQL instance"
  type        = bool
  default     = true
}

variable "cloud_sql_tier" {
  description = "Cloud SQL machine tier"
  type        = string
  default     = "db-f1-micro"
}

variable "cloud_sql_disk_size" {
  description = "Cloud SQL disk size in GB"
  type        = number
  default     = 20
}

variable "cloud_sql_database_version" {
  description = "PostgreSQL version for Cloud SQL"
  type        = string
  default     = "POSTGRES_15"
}

variable "cloud_sql_database_name" {
  description = "Name of the default database"
  type        = string
  default     = "appdb"
}

variable "cloud_sql_ha" {
  description = "Enable high availability for Cloud SQL"
  type        = bool
  default     = false
}

variable "cloud_sql_deletion_protection" {
  description = "Enable deletion protection for Cloud SQL"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# VPC Connector Configuration
# -----------------------------------------------------------------------------

variable "vpc_connector_cidr" {
  description = "CIDR range for VPC Connector (must be /28, unused by other resources)"
  type        = string
  default     = "10.0.100.0/28"
}
