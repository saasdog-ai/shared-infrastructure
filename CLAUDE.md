# CLAUDE.md — Shared Infrastructure

## What Is This Project?

Terraform configuration for shared AWS infrastructure (VPC, ECS Fargate cluster, RDS PostgreSQL) used by multiple application services. Designed for on-demand dev environments — spin up when needed, tear down when idle.

## Tech Stack

- **Terraform** >= 1.5.0, AWS provider ~> 5.0
- **AWS services**: VPC, ECS (Fargate), RDS PostgreSQL 15, NAT Gateway, Secrets Manager
- **CI/CD**: GitHub Actions with OIDC authentication (no long-lived credentials)
- **State**: S3 + DynamoDB locking (created by bootstrap)

## Project Structure

```
infra/aws/terraform/
  bootstrap/main.tf    # One-time: creates S3 state bucket + DynamoDB lock table
  versions.tf          # Terraform/provider versions, S3 backend (partial config)
  variables.tf         # All configurable variables
  main.tf              # VPC, ECS cluster, RDS, security groups, NAT Gateway
  outputs.tf           # Outputs consumed by application projects
  terraform.tfvars.example  # Template for local config
.github/workflows/terraform.yml  # CI/CD pipeline
```

## Key Architecture Decisions

- **Partial S3 backend**: `backend "s3" {}` — bucket/table names passed via `-backend-config` flags (not hardcoded)
- **Conditional resource creation**: `create_vpc`, `create_ecs_cluster`, `create_rds` flags allow reusing existing infra
- **Single NAT Gateway**: Cost optimization for dev (~$32/mo vs $64/mo for HA)
- **RDS master credentials**: Applications use master creds directly; `start.sh` auto-creates databases. No manual DBA step.
- **Secrets Manager**: RDS master password auto-generated and stored; recovery_window=0 for dev (instant delete on destroy)
- **company_prefix variable**: No default — must be set in tfvars. All resource names use `<company_prefix>-shared-*-<env>` pattern.

## Deployment Flow

```
1. Bootstrap (one-time):  cd bootstrap && terraform init && terraform apply -var="company_prefix=mycompany"
2. Init with backend:     terraform init -backend-config="bucket=mycompany-shared-infra-tfstate-dev" ...
3. Apply:                 terraform apply
4. Outputs feed into:     integration-platform, import-export-orchestrator (as TF_VAR_shared_* variables)
```

Or use the orchestration script from the parent project: `./scripts/infra.sh up`

## Outputs Consumed by Applications

| Output | Used For |
|--------|----------|
| `vpc_id` | Application security groups |
| `public_subnet_ids` | ALB placement |
| `private_subnet_ids` | ECS tasks, RDS subnet group |
| `ecs_cluster_arn` / `ecs_cluster_name` | ECS service definition |
| `rds_endpoint` / `rds_address` | DATABASE_URL construction |
| `rds_security_group_id` | Application SG ingress rules |
| `rds_master_password_secret_arn` | Application reads password from Secrets Manager |

## Cost Profile (dev, single-AZ, db.t3.micro)

| Resource | Monthly |
|----------|---------|
| NAT Gateway | ~$32 |
| RDS db.t3.micro | ~$13 |
| Secrets Manager | ~$1 |
| ECS cluster (no tasks) | $0 |
| **Total (infra only)** | **~$46** |

Application costs (ALB, Fargate tasks, SQS, KMS) are additional per-app.

## Conventions

- All resource names: `<company_prefix>-shared-<resource>-<env>`
- Bootstrap resources have `prevent_destroy = true` (state bucket + lock table persist across destroy cycles)
- `.gitignore` excludes: `*.tfstate`, `*.tfvars` (not example), `tfplan`, `.terraform/`
- Commits directly to `main`

## Sister Projects

- **integration-platform**: SaaS integration sync engine (first consumer of this infra)
- **import-export-orchestrator**: Async import/export job runner
- **scripts/infra.sh** (in parent): One-command up/down for shared-infra + integration-platform
