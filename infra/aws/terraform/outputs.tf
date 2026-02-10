# -----------------------------------------------------------------------------
# VPC Outputs
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC"
  value       = local.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = var.create_vpc ? aws_vpc.main[0].cidr_block : ""
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = local.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = local.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "IDs of NAT gateways"
  value       = var.create_vpc && var.enable_nat_gateway ? aws_nat_gateway.main[*].id : []
}

# -----------------------------------------------------------------------------
# ECS Cluster Outputs
# -----------------------------------------------------------------------------

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = local.ecs_cluster_arn
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = local.ecs_cluster_name
}

# -----------------------------------------------------------------------------
# RDS Outputs
# -----------------------------------------------------------------------------

output "rds_endpoint" {
  description = "Endpoint of the RDS instance"
  value       = var.create_rds ? aws_db_instance.main[0].endpoint : var.existing_rds_endpoint
}

output "rds_address" {
  description = "Address (hostname) of the RDS instance"
  value       = var.create_rds ? aws_db_instance.main[0].address : split(":", var.existing_rds_endpoint)[0]
}

output "rds_port" {
  description = "Port of the RDS instance"
  value       = var.create_rds ? aws_db_instance.main[0].port : var.existing_rds_port
}

output "rds_database_name" {
  description = "Name of the default database"
  value       = var.create_rds ? aws_db_instance.main[0].db_name : ""
}

output "rds_master_username" {
  description = "Master username"
  value       = var.create_rds ? aws_db_instance.main[0].username : ""
  sensitive   = true
}

output "rds_security_group_id" {
  description = "Security group ID for RDS"
  value       = var.create_rds ? aws_security_group.rds[0].id : var.existing_rds_security_group_id
}

output "rds_master_password_secret_arn" {
  description = "ARN of the secret containing RDS master password"
  value       = var.create_rds ? aws_secretsmanager_secret.rds_master_password[0].arn : ""
}

# -----------------------------------------------------------------------------
# Summary Output (for easy reference)
# -----------------------------------------------------------------------------

output "shared_infrastructure_summary" {
  description = "Summary of shared infrastructure for use by application projects"
  value = {
    vpc_id              = local.vpc_id
    public_subnet_ids   = local.public_subnet_ids
    private_subnet_ids  = local.private_subnet_ids
    ecs_cluster_arn     = local.ecs_cluster_arn
    ecs_cluster_name    = local.ecs_cluster_name
    rds_endpoint        = var.create_rds ? aws_db_instance.main[0].endpoint : var.existing_rds_endpoint
    rds_security_group  = var.create_rds ? aws_security_group.rds[0].id : var.existing_rds_security_group_id
  }
}
