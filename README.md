# Shared Infrastructure

Terraform configuration for shared AWS infrastructure used by multiple applications.

## Overview

This project deploys foundational infrastructure that is shared across applications:

- **VPC** with public and private subnets across 2 AZs
- **ECS Cluster** (Fargate) for container orchestration
- **RDS PostgreSQL** shared database instance
- **NAT Gateway** for private subnet internet access

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                            AWS Account                               │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                         VPC (10.0.0.0/16)                       │ │
│  │                                                                  │ │
│  │  ┌─────────────────────┐    ┌─────────────────────┐            │ │
│  │  │   Public Subnets    │    │   Private Subnets   │            │ │
│  │  │  10.0.1.0/24 (AZ1)  │    │  10.0.10.0/24 (AZ1) │            │ │
│  │  │  10.0.2.0/24 (AZ2)  │    │  10.0.11.0/24 (AZ2) │            │ │
│  │  │                     │    │                     │            │ │
│  │  │  ┌─────────────┐    │    │  ┌─────────────┐    │            │ │
│  │  │  │ NAT Gateway │◄───┼────┼──│ ECS Tasks   │    │            │ │
│  │  │  └─────────────┘    │    │  └─────────────┘    │            │ │
│  │  │                     │    │                     │            │ │
│  │  │                     │    │  ┌─────────────┐    │            │ │
│  │  │                     │    │  │     RDS     │    │            │ │
│  │  │                     │    │  │ PostgreSQL  │    │            │ │
│  │  │                     │    │  └─────────────┘    │            │ │
│  │  └─────────────────────┘    └─────────────────────┘            │ │
│  │                                                                  │ │
│  │  ┌────────────────────────────────────────────────────────────┐ │ │
│  │  │                    ECS Cluster (Fargate)                    │ │ │
│  │  │  Shared cluster for all application services                │ │ │
│  │  └────────────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- AWS CLI configured
- Terraform >= 1.0

## Deployment

### Step 1: Bootstrap State Backend

```bash
cd infra/aws/terraform/bootstrap
terraform init
terraform apply
```

This creates:
- S3 bucket for Terraform state
- DynamoDB table for state locking

### Step 2: Configure Variables

```bash
cd infra/aws/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
company_prefix = "your-company"
environment    = "dev"
aws_region     = "us-east-1"

# RDS
rds_instance_class = "db.t3.micro"  # Production: db.t3.small+
```

### Step 3: Deploy

```bash
# Backend bucket/table names follow: <company_prefix>-shared-infra-tfstate-<env>
terraform init \
  -backend-config="bucket=mycompany-shared-infra-tfstate-dev" \
  -backend-config="key=terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=mycompany-shared-infra-tflock-dev" \
  -backend-config="encrypt=true"

terraform apply
```

### Step 4: Note Outputs

After deployment, note these outputs for application deployments:

```bash
terraform output
```

Key outputs:
| Output | Description | Used By |
|--------|-------------|---------|
| `vpc_id` | VPC identifier | Application terraform.tfvars |
| `public_subnet_ids` | Public subnet IDs | ALB placement |
| `private_subnet_ids` | Private subnet IDs | ECS tasks, RDS |
| `ecs_cluster_arn` | ECS cluster ARN | Application ECS service |
| `ecs_cluster_name` | ECS cluster name | Application ECS service |
| `rds_endpoint` | RDS endpoint with port | DATABASE_URL |
| `rds_address` | RDS hostname only | DATABASE_URL |
| `rds_security_group_id` | RDS security group | Application SG rules |
| `rds_master_password_secret_arn` | Master password secret | DBA access |

## Applications Using This Infrastructure

- **integration-platform** - Integration sync service
- **import-export-orchestrator** - Data import/export service

Each application:
1. References shared infrastructure outputs in their `terraform.tfvars`
2. Creates their own database on the shared RDS (via DBA script)
3. Deploys ECS service to the shared cluster
4. Creates application-specific resources (ALB, SQS, S3, etc.)

## Database Management

The shared RDS instance hosts multiple application databases (e.g., `integration_platform`, `job_runner`).

Application containers use RDS master credentials and auto-create their database on first boot via their `start.sh` entrypoint — no manual DBA step required.

```bash
# Get master password (if needed for manual access)
aws secretsmanager get-secret-value \
  --secret-id "<company_prefix>-shared-rds-master-password-<env>" \
  --query 'SecretString' --output text
```

## Security Considerations

- RDS is in private subnets (no public access)
- RDS master password stored in Secrets Manager
- Security group rules control access to RDS
- For production, create separate per-app database users with least privilege

## Cost Optimization

For development/testing:
- Single NAT Gateway (vs. one per AZ)
- `db.t3.micro` RDS instance
- Fargate Spot for non-production workloads

For production:
- NAT Gateway per AZ for high availability
- Right-sized RDS instance
- Multi-AZ RDS deployment
- Enable RDS Performance Insights
