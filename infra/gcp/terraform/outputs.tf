# -----------------------------------------------------------------------------
# VPC Outputs
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC network"
  value       = var.create_vpc ? google_compute_network.main[0].id : ""
}

output "vpc_name" {
  description = "Name of the VPC network"
  value       = var.create_vpc ? google_compute_network.main[0].name : ""
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = var.create_vpc ? google_compute_subnetwork.public[0].id : ""
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = var.create_vpc ? google_compute_subnetwork.private[0].id : ""
}

output "vpc_connector_id" {
  description = "ID of the VPC Connector for Cloud Run"
  value       = var.create_vpc ? google_vpc_access_connector.main[0].id : ""
}

# -----------------------------------------------------------------------------
# Cloud SQL Outputs
# -----------------------------------------------------------------------------

output "cloud_sql_instance_name" {
  description = "Name of the Cloud SQL instance"
  value       = var.create_cloud_sql ? google_sql_database_instance.main[0].name : ""
}

output "cloud_sql_connection_name" {
  description = "Connection name for Cloud SQL (project:region:instance)"
  value       = var.create_cloud_sql ? google_sql_database_instance.main[0].connection_name : ""
}

output "cloud_sql_private_ip" {
  description = "Private IP address of Cloud SQL"
  value       = var.create_cloud_sql ? google_sql_database_instance.main[0].private_ip_address : ""
}

output "cloud_sql_database_name" {
  description = "Name of the default database"
  value       = var.create_cloud_sql ? google_sql_database.main[0].name : ""
}

output "cloud_sql_master_password_secret_id" {
  description = "Secret Manager secret ID for Cloud SQL master password"
  value       = var.create_cloud_sql ? google_secret_manager_secret.cloud_sql_master_password[0].secret_id : ""
}

# -----------------------------------------------------------------------------
# Summary Output
# -----------------------------------------------------------------------------

output "shared_infrastructure_summary" {
  description = "Summary of shared infrastructure for use by application projects"
  value = {
    vpc_id                              = var.create_vpc ? google_compute_network.main[0].id : ""
    vpc_connector_id                    = var.create_vpc ? google_vpc_access_connector.main[0].id : ""
    cloud_sql_connection_name           = var.create_cloud_sql ? google_sql_database_instance.main[0].connection_name : ""
    cloud_sql_private_ip                = var.create_cloud_sql ? google_sql_database_instance.main[0].private_ip_address : ""
    cloud_sql_master_password_secret_id = var.create_cloud_sql ? google_secret_manager_secret.cloud_sql_master_password[0].secret_id : ""
  }
}
