# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------

locals {
  name_prefix = "${var.company_prefix}-shared"

  # Use created or existing resources
  vpc_id              = var.create_vpc ? aws_vpc.main[0].id : var.existing_vpc_id
  public_subnet_ids   = var.create_vpc ? aws_subnet.public[*].id : var.existing_public_subnet_ids
  private_subnet_ids  = var.create_vpc ? aws_subnet.private[*].id : var.existing_private_subnet_ids
  ecs_cluster_arn     = var.create_ecs_cluster ? aws_ecs_cluster.main[0].arn : var.existing_ecs_cluster_arn
  ecs_cluster_name    = var.create_ecs_cluster ? aws_ecs_cluster.main[0].name : split("/", var.existing_ecs_cluster_arn)[1]

  common_tags = {
    Project     = "shared-infrastructure"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

resource "aws_vpc" "main" {
  count = var.create_vpc ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-vpc-${var.environment}"
  }

  lifecycle {
    prevent_destroy = false  # Set to true for production
  }
}

resource "aws_internet_gateway" "main" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  tags = {
    Name = "${local.name_prefix}-igw-${var.environment}"
  }
}

# -----------------------------------------------------------------------------
# Subnets
# -----------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = var.create_vpc ? length(var.public_subnet_cidrs) : 0

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-${count.index + 1}-${var.environment}"
    Type = "public"
  }
}

resource "aws_subnet" "private" {
  count = var.create_vpc ? length(var.private_subnet_cidrs) : 0

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${local.name_prefix}-private-${count.index + 1}-${var.environment}"
    Type = "private"
  }
}

# -----------------------------------------------------------------------------
# NAT Gateway
# -----------------------------------------------------------------------------

resource "aws_eip" "nat" {
  count = var.create_vpc && var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0

  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-eip-${count.index + 1}-${var.environment}"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count = var.create_vpc && var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${local.name_prefix}-nat-${count.index + 1}-${var.environment}"
  }

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# Route Tables
# -----------------------------------------------------------------------------

resource "aws_route_table" "public" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt-${var.environment}"
  }
}

resource "aws_route_table_association" "public" {
  count = var.create_vpc ? length(var.public_subnet_cidrs) : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table" "private" {
  count = var.create_vpc && var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[var.single_nat_gateway ? 0 : count.index].id
  }

  tags = {
    Name = "${local.name_prefix}-private-rt-${count.index + 1}-${var.environment}"
  }
}

resource "aws_route_table_association" "private" {
  count = var.create_vpc ? length(var.private_subnet_cidrs) : 0

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}

# -----------------------------------------------------------------------------
# ECS Cluster
# -----------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  count = var.create_ecs_cluster ? 1 : 0

  name = "${local.name_prefix}-ecs-${var.environment}"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = {
    Name = "${local.name_prefix}-ecs-${var.environment}"
  }

  lifecycle {
    prevent_destroy = false  # Set to true for production
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  count = var.create_ecs_cluster ? 1 : 0

  cluster_name = aws_ecs_cluster.main[0].name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# -----------------------------------------------------------------------------
# RDS Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "rds" {
  count = var.create_rds ? 1 : 0

  name        = "${local.name_prefix}-rds-sg-${var.environment}"
  description = "Security group for shared RDS instance"
  vpc_id      = local.vpc_id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.create_vpc ? var.vpc_cidr : "10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-rds-sg-${var.environment}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# RDS Subnet Group
# -----------------------------------------------------------------------------

resource "aws_db_subnet_group" "main" {
  count = var.create_rds ? 1 : 0

  name        = "${local.name_prefix}-rds-subnet-${var.environment}"
  description = "Subnet group for shared RDS"
  subnet_ids  = local.private_subnet_ids

  tags = {
    Name = "${local.name_prefix}-rds-subnet-${var.environment}"
  }
}

# -----------------------------------------------------------------------------
# RDS Instance
# -----------------------------------------------------------------------------

resource "random_password" "rds_master" {
  count = var.create_rds ? 1 : 0

  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "rds_master_password" {
  count = var.create_rds ? 1 : 0

  name                    = "${local.name_prefix}-rds-master-password-${var.environment}"
  description             = "Master password for shared RDS instance"
  recovery_window_in_days = 0

  tags = {
    Name = "${local.name_prefix}-rds-master-password-${var.environment}"
  }
}

resource "aws_secretsmanager_secret_version" "rds_master_password" {
  count = var.create_rds ? 1 : 0

  secret_id     = aws_secretsmanager_secret.rds_master_password[0].id
  secret_string = random_password.rds_master[0].result
}

resource "aws_db_instance" "main" {
  count = var.create_rds ? 1 : 0

  identifier = "${local.name_prefix}-rds-${var.environment}"

  engine         = "postgres"
  engine_version = var.rds_engine_version
  instance_class = var.rds_instance_class

  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.rds_database_name
  username = var.rds_master_username
  password = random_password.rds_master[0].result

  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  vpc_security_group_ids = [aws_security_group.rds[0].id]

  multi_az               = var.rds_multi_az
  publicly_accessible    = false
  skip_final_snapshot    = var.rds_skip_final_snapshot
  deletion_protection    = var.rds_deletion_protection

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "Mon:04:00-Mon:05:00"

  performance_insights_enabled = false  # Enable for prod

  tags = {
    Name = "${local.name_prefix}-rds-${var.environment}"
  }

  lifecycle {
    prevent_destroy = false  # Set to true for production
  }
}
