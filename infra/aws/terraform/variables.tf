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

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# -----------------------------------------------------------------------------
# VPC Configuration
# -----------------------------------------------------------------------------

variable "create_vpc" {
  description = "Whether to create a new VPC (false if using existing)"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway (cost savings for non-prod)"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# ECS Cluster Configuration
# -----------------------------------------------------------------------------

variable "create_ecs_cluster" {
  description = "Whether to create a new ECS cluster"
  type        = bool
  default     = true
}

variable "ecs_cluster_name" {
  description = "Name for the ECS cluster (without prefix/suffix)"
  type        = string
  default     = "shared"
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# RDS Configuration
# -----------------------------------------------------------------------------

variable "create_rds" {
  description = "Whether to create a new RDS instance"
  type        = bool
  default     = true
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "rds_database_name" {
  description = "Name of the default database"
  type        = string
  default     = "appdb"
}

variable "rds_master_username" {
  description = "Master username for RDS"
  type        = string
  default     = "postgres"
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "rds_skip_final_snapshot" {
  description = "Skip final snapshot on deletion (set false for prod)"
  type        = bool
  default     = true
}

variable "rds_deletion_protection" {
  description = "Enable deletion protection (set true for prod)"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Existing Infrastructure (when not creating new)
# -----------------------------------------------------------------------------

variable "existing_vpc_id" {
  description = "ID of existing VPC (when create_vpc = false)"
  type        = string
  default     = ""
}

variable "existing_public_subnet_ids" {
  description = "IDs of existing public subnets"
  type        = list(string)
  default     = []
}

variable "existing_private_subnet_ids" {
  description = "IDs of existing private subnets"
  type        = list(string)
  default     = []
}

variable "existing_ecs_cluster_arn" {
  description = "ARN of existing ECS cluster (when create_ecs_cluster = false)"
  type        = string
  default     = ""
}

variable "existing_rds_endpoint" {
  description = "Endpoint of existing RDS (when create_rds = false)"
  type        = string
  default     = ""
}

variable "existing_rds_port" {
  description = "Port of existing RDS"
  type        = number
  default     = 5432
}

variable "existing_rds_security_group_id" {
  description = "Security group ID of existing RDS"
  type        = string
  default     = ""
}
