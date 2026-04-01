# Setup From Scratch Guide

Complete guide to deploy the SaaSDog platform from zero after a `terraform destroy`.

## System Overview

Three projects deployed to AWS:

| Project | Database | ECS Service | Ports |
|---------|----------|-------------|-------|
| **shared-infrastructure** | RDS PostgreSQL 15 (db.t3.micro) | N/A | 5432 |
| **integration-platform** | `integration_platform` DB on shared RDS | `saasdog-integration-platform-dev` | 8000 |
| **import-export-orchestrator** | `job_runner` DB on shared RDS | `saasdog-import-export-dev` | 8000 |

Deploy order: **shared-infrastructure** → **integration-platform** + **import-export-orchestrator** (parallel)

## AWS Account

- **Account ID**: `429763994533`
- **Region**: `us-east-1`
- **Company prefix**: `saasdog`
- **Environment**: `dev`

## Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform >= 1.5.0
- Docker (with `buildx` for cross-platform builds)
- PostgreSQL client (`psql`) for seeding

---

## Step 1: Deploy shared-infrastructure

### 1a. Bootstrap Terraform state (one-time)

```bash
cd shared-infrastructure/infra/aws/terraform/bootstrap
terraform init
terraform apply -var="company_prefix=saasdog"
```

This creates:
- S3 bucket: `saasdog-shared-infra-tfstate-dev`
- DynamoDB table: `saasdog-shared-infra-tflock-dev`

### 1b. Create `terraform.tfvars`

```bash
cd shared-infrastructure/infra/aws/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
company_prefix = "saasdog"
environment    = "dev"
aws_region     = "us-east-1"

create_vpc         = true
create_ecs_cluster = true
create_rds         = true

vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
enable_nat_gateway   = true
single_nat_gateway   = true

rds_instance_class      = "db.t3.micro"
rds_allocated_storage   = 20
rds_engine_version      = "15.4"
rds_database_name       = "appdb"
rds_master_username     = "postgres"
rds_multi_az            = false
rds_skip_final_snapshot = true
rds_deletion_protection = false
```

### 1c. Init and apply

```bash
terraform init \
  -backend-config="bucket=saasdog-shared-infra-tfstate-dev" \
  -backend-config="key=terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=saasdog-shared-infra-tflock-dev"

terraform apply
```

### 1d. Save outputs (needed by application projects)

```bash
terraform output -json > /tmp/shared-infra-outputs.json

# Key values you'll need:
terraform output vpc_id
terraform output public_subnet_ids
terraform output private_subnet_ids
terraform output ecs_cluster_arn
terraform output ecs_cluster_name
terraform output rds_endpoint
terraform output rds_address
terraform output rds_security_group_id
terraform output rds_master_password_secret_arn
```

---

## Step 2: Deploy integration-platform

### 2a. Bootstrap Terraform state

```bash
cd integration-platform/infra/aws/terraform/bootstrap
terraform init
terraform apply -var="company_prefix=saasdog" -var="app_name=integration-platform"
```

### 2b. Create `terraform.tfvars`

```bash
cd integration-platform/infra/aws/terraform
cp terraform.tfvars.example terraform.tfvars
```

Fill in with shared-infrastructure outputs:
```hcl
company_prefix = "saasdog"
environment    = "dev"
aws_region     = "us-east-1"
app_name       = "integration-platform"

# From shared-infrastructure outputs
shared_vpc_id                         = "<vpc_id from step 1d>"
shared_public_subnet_ids              = ["<subnet-1>", "<subnet-2>"]
shared_private_subnet_ids             = ["<subnet-3>", "<subnet-4>"]
shared_ecs_cluster_arn                = "<ecs_cluster_arn from step 1d>"
shared_ecs_cluster_name               = "saasdog-shared-ecs-dev"
shared_rds_endpoint                   = "<rds_endpoint from step 1d>"
shared_rds_address                    = "<rds_address from step 1d>"
shared_rds_security_group_id          = "<rds_security_group_id from step 1d>"
shared_rds_master_password_secret_arn = "<rds_master_password_secret_arn from step 1d>"

db_name     = "integration_platform"
db_username = "integration_platform"

ecs_task_cpu      = 256
ecs_task_memory   = 512
ecs_desired_count = 1
container_port    = 8000

enable_deletion_protection = false
```

### 2c. Init and apply

```bash
terraform init \
  -backend-config="bucket=saasdog-integration-platform-tfstate-dev" \
  -backend-config="key=terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=saasdog-integration-platform-tflock-dev"

terraform apply
```

### 2d. Build and push Docker image

```bash
cd integration-platform

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 429763994533.dkr.ecr.us-east-1.amazonaws.com

# Build for linux/amd64 (required for Fargate — Mac builds arm64 by default)
docker buildx build --platform linux/amd64 --no-cache \
  -t 429763994533.dkr.ecr.us-east-1.amazonaws.com/saasdog-integration-platform-dev:latest \
  --push .

# Force ECS to pick up the new image
aws ecs update-service --cluster saasdog-shared-ecs-dev \
  --service saasdog-integration-platform-dev \
  --force-new-deployment
```

The container's `start.sh` automatically:
1. Creates the `integration_platform` database if it doesn't exist
2. Runs all Alembic migrations
3. Starts uvicorn

---

## Step 3: Deploy import-export-orchestrator

### 3a. Bootstrap Terraform state

```bash
cd import-export-orchestrator/infra/aws/terraform/bootstrap
terraform init
terraform apply -var="company_prefix=saasdog" -var="app_name=import-export"
```

### 3b. Create `terraform.tfvars`

```bash
cd import-export-orchestrator/infra/aws/terraform
cp terraform.tfvars.example terraform.tfvars
```

Fill in with shared-infrastructure outputs (same values as step 2b):
```hcl
company_prefix = "saasdog"
environment    = "dev"
aws_region     = "us-east-1"
app_name       = "import-export"

# From shared-infrastructure outputs (same as integration-platform)
shared_vpc_id                         = "<vpc_id>"
shared_public_subnet_ids              = ["<subnet-1>", "<subnet-2>"]
shared_private_subnet_ids             = ["<subnet-3>", "<subnet-4>"]
shared_ecs_cluster_arn                = "<ecs_cluster_arn>"
shared_ecs_cluster_name               = "saasdog-shared-ecs-dev"
shared_rds_endpoint                   = "<rds_endpoint>"
shared_rds_address                    = "<rds_address>"
shared_rds_security_group_id          = "<rds_security_group_id>"
shared_rds_master_password_secret_arn = "<rds_master_password_secret_arn>"

db_name     = "job_runner"
db_username = "job_runner"

ecs_task_cpu      = 512
ecs_task_memory   = 1024
ecs_desired_count = 1

enable_deletion_protection = false
```

### 3c. Init and apply

```bash
terraform init \
  -backend-config="bucket=saasdog-import-export-tfstate-dev" \
  -backend-config="key=terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=saasdog-import-export-tflock-dev"

terraform apply
```

### 3d. Build and push Docker image

```bash
cd import-export-orchestrator

aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 429763994533.dkr.ecr.us-east-1.amazonaws.com

docker buildx build --platform linux/amd64 --no-cache \
  -t 429763994533.dkr.ecr.us-east-1.amazonaws.com/saasdog-import-export-dev:latest \
  --push .

aws ecs update-service --cluster saasdog-shared-ecs-dev \
  --service saasdog-import-export-dev \
  --force-new-deployment
```

---

## Step 4: Set Up Secrets

### Secrets created automatically by Terraform

| Secret Name | Created By | Purpose |
|-------------|-----------|---------|
| `saasdog-shared-rds-master-password-dev` | shared-infrastructure | RDS master password (auto-generated) |
| `saasdog-integration-platform-database-url-dev` | integration-platform | Full DATABASE_URL (auto-constructed from RDS master password) |
| `saasdog-import-export-database-url-dev` | import-export-orchestrator | Full DATABASE_URL (auto-constructed) |
| `saasdog-integration-platform-admin-api-key-dev` | integration-platform | Secrets Manager secret (shell only — value must be set manually) |

### Set Admin API Key (manual)

The Terraform creates the secret shell but not the value. Set it:

```bash
# Generate a key
ADMIN_KEY=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)
echo "Admin API Key: $ADMIN_KEY"   # Save this!

# Store in Secrets Manager
aws secretsmanager put-secret-value \
  --secret-id "saasdog-integration-platform-admin-api-key-dev" \
  --secret-string "$ADMIN_KEY"
```

Save the admin API key — you'll need it for:
- `admin-host-app` configuration (vite.config.ts proxy headers)
- Direct admin API calls via `X-Admin-API-Key` header

---

## Step 5: Set Up OAuth Credentials (QBO & Xero)

**Important**: QBO and Xero OAuth credentials are NOT managed by Terraform. They're passed as environment variables to the ECS task definition. You need to:
1. Get credentials from the developer portals
2. Add them to the ECS task definition environment variables

### 5a. QuickBooks Online (QBO)

1. Go to https://developer.intuit.com/
2. Sign in → Dashboard → Create an app (or select existing)
3. App type: select "QuickBooks Online and Payments"
4. Get your credentials from the app's **Keys & credentials** page:
   - **Client ID** (`QBO_CLIENT_ID`)
   - **Client Secret** (`QBO_CLIENT_SECRET`)
5. Configure **Redirect URIs**:
   - Development: `http://localhost:8001/integrations/11111111-1111-1111-1111-111111111111/callback`
   - Production: `https://<your-alb-url>/integrations/11111111-1111-1111-1111-111111111111/callback`
6. **Environment**: `sandbox` for testing, `production` for real data
   - Set `QBO_ENVIRONMENT=sandbox` or `QBO_ENVIRONMENT=production`

### 5b. Xero

1. Go to https://developer.xero.com/
2. Sign in → My Apps → New App
3. App type: Web app
4. Get your credentials:
   - **Client ID** (`XERO_CLIENT_ID`)
   - **Client Secret** (`XERO_CLIENT_SECRET`)
5. Configure **Redirect URI**:
   - Development: `http://localhost:8001/integrations/22222222-2222-2222-2222-222222222222/callback`
   - Production: `https://<your-alb-url>/integrations/22222222-2222-2222-2222-222222222222/callback`
6. **Required scopes** (configured in seed data):
   - `openid profile email`
   - `accounting.contacts.read accounting.contacts`
   - `accounting.transactions.read accounting.transactions`
   - `accounting.settings.read accounting.settings`
   - `offline_access`

### 5c. Add OAuth credentials to ECS task definition

After getting credentials, update the ECS task definition to include them. You can do this by:

**Option A: Add to Terraform `ecs.tf`** (recommended for persistence across deploys)

Edit `integration-platform/infra/aws/terraform/ecs.tf`, add to the `environment` block:

```hcl
{ name = "QBO_CLIENT_ID", value = "<your-qbo-client-id>" },
{ name = "QBO_CLIENT_SECRET", value = "<your-qbo-client-secret>" },
{ name = "QBO_ENVIRONMENT", value = "sandbox" },
{ name = "XERO_CLIENT_ID", value = "<your-xero-client-id>" },
{ name = "XERO_CLIENT_SECRET", value = "<your-xero-client-secret>" },
```

Then `terraform apply` and force new ECS deployment.

**Option B: Store in Secrets Manager** (more secure)

```bash
# Create secrets
aws secretsmanager create-secret --name "saasdog-qbo-client-id-dev" --secret-string "<your-qbo-client-id>"
aws secretsmanager create-secret --name "saasdog-qbo-client-secret-dev" --secret-string "<your-qbo-client-secret>"
aws secretsmanager create-secret --name "saasdog-xero-client-id-dev" --secret-string "<your-xero-client-id>"
aws secretsmanager create-secret --name "saasdog-xero-client-secret-dev" --secret-string "<your-xero-client-secret>"
```

Then reference them in the ECS task definition's `secrets` block and grant the task execution role read access.

---

## Step 6: Seed the Database

### 6a. Set up bastion host / SSH tunnel for DB access

The RDS instance is in a private subnet and not publicly accessible. You need a bastion host to connect:

```bash
# Create a bastion host (if not already running)
# Or use AWS Systems Manager Session Manager

# SSH tunnel to RDS
ssh -f -N -L 15432:<rds-address>:5432 \
  -i ~/.ssh/<bastion-key>.pem \
  ec2-user@<bastion-ip>
```

### 6b. Get the RDS master password

```bash
aws secretsmanager get-secret-value \
  --secret-id "saasdog-shared-rds-master-password-dev" \
  --query 'SecretString' --output text
```

### 6c. Seed integration-platform catalog

The container's `start.sh` auto-creates the database and runs Alembic migrations. After the first successful deployment, seed the integration catalog:

```bash
# Connect using RDS master credentials
PGPASSWORD="<rds-master-password>" psql \
  -h localhost -p 15432 \
  -U postgres \
  -d integration_platform \
  -f integration-platform/scripts/seed_sample_data.sql
```

This creates:
- **5 available integrations**: QuickBooks Online, Xero, NetSuite, Sage Intacct, HubSpot
  - Fixed UUIDs: QBO=`11111111-...`, Xero=`22222222-...`, NetSuite=`33333333-...`, Sage=`44444444-...`, HubSpot=`55555555-...`
- **2 system default settings**: QBO and Xero sync rules
  - Default sync direction: chart_of_accounts/vendor/customer/item = inbound, bill/invoice/payment = outbound
  - Default frequency: every 6 hours (`0 */6 * * *`), auto-sync disabled

### 6d. Seed import-export-orchestrator sample data (optional)

```bash
cd import-export-orchestrator
DATABASE_URL="postgresql+asyncpg://postgres:<password>@localhost:15432/job_runner" \
  python -m scripts.seed_sample_data
```

This creates sample vendors, projects, bills, and invoices for testing import/export operations.

---

## Step 7: Verify Deployment

### Health checks

```bash
# Get ALB URLs from Terraform outputs
# integration-platform ALB:
curl -s https://<integration-platform-alb>/health
curl -s https://<integration-platform-alb>/docs   # Swagger UI

# import-export-orchestrator ALB:
curl -s https://<import-export-alb>/health
curl -s https://<import-export-alb>/docs
```

### Verify integration catalog

```bash
curl -s https://<integration-platform-alb>/integrations/available | python -m json.tool
```

Should return 5 integrations (QBO, Xero, NetSuite, Sage, HubSpot).

### Verify admin API

```bash
curl -s -H "X-Admin-API-Key: <your-admin-key>" \
  https://<integration-platform-alb>/admin/integrations/available | python -m json.tool
```

---

## Step 8: Configure Host Apps

### Update ALB URLs in host apps

**saas-host-app** (`vite.config.local.ts`):
- `/api/*` proxy → import-export-orchestrator ALB URL
- `/int-api/*` proxy → integration-platform ALB URL

**admin-host-app** (`vite.config.ts`):
- `/int-api/*` proxy → integration-platform ALB URL
- `X-Admin-API-Key` header → the admin key from Step 4

---

## Terraform Destroy Order

When tearing down, destroy in reverse order:

```bash
# 1. Destroy application services first
cd integration-platform/infra/aws/terraform
terraform init -backend-config="bucket=saasdog-integration-platform-tfstate-dev" \
  -backend-config="key=terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=saasdog-integration-platform-tflock-dev"
terraform destroy

cd import-export-orchestrator/infra/aws/terraform
terraform init -backend-config="bucket=saasdog-import-export-tfstate-dev" \
  -backend-config="key=terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=saasdog-import-export-tflock-dev"
terraform destroy

# 2. Destroy shared infrastructure last
cd shared-infrastructure/infra/aws/terraform
terraform init -backend-config="bucket=saasdog-shared-infra-tfstate-dev" \
  -backend-config="key=terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=saasdog-shared-infra-tflock-dev"
terraform destroy
```

**Note**: Bootstrap resources (S3 state buckets, DynamoDB lock tables) are NOT destroyed by `terraform destroy` — they have `prevent_destroy = true`. This is intentional so you can re-deploy later without losing state configuration.

---

## Environment Variables Reference

### integration-platform (ECS task)

| Variable | Source | Purpose |
|----------|--------|---------|
| `DATABASE_URL` | Secrets Manager (auto) | PostgreSQL connection string |
| `ADMIN_API_KEY` | Secrets Manager (manual) | Admin endpoint authentication |
| `APP_ENV` | Terraform | `development` / `production` |
| `API_PORT` | Terraform | `8000` |
| `CLOUD_PROVIDER` | Terraform | `aws` |
| `AWS_REGION` | Terraform | `us-east-1` |
| `QUEUE_URL` | Terraform | SQS queue URL |
| `KMS_KEY_ID` | Terraform | KMS key for credential encryption |
| `QBO_CLIENT_ID` | Manual | QuickBooks OAuth client ID |
| `QBO_CLIENT_SECRET` | Manual | QuickBooks OAuth client secret |
| `QBO_ENVIRONMENT` | Manual | `sandbox` or `production` |
| `XERO_CLIENT_ID` | Manual | Xero OAuth client ID |
| `XERO_CLIENT_SECRET` | Manual | Xero OAuth client secret |
| `AUTH_ENABLED` | Terraform | `false` (dev) / `true` (prod) |
| `JWT_SECRET_KEY` | Manual (if auth enabled) | JWT signing key |

### import-export-orchestrator (ECS task)

| Variable | Source | Purpose |
|----------|--------|---------|
| `DATABASE_URL` | Secrets Manager (auto) | PostgreSQL connection string |
| `APP_ENV` | Terraform | `development` / `production` |
| `API_PORT` | Terraform | `8000` |
| `CLOUD_PROVIDER` | Terraform | `aws` |
| `AWS_REGION` | Terraform | `us-east-1` |

---

## Cost Estimate (dev environment)

| Resource | Monthly Cost |
|----------|-------------|
| NAT Gateway | ~$32 |
| RDS db.t3.micro | ~$13 |
| ECS Fargate (2 services, 0.25-0.5 vCPU) | ~$20-40 |
| ALB (2 load balancers) | ~$32 |
| SQS, KMS, Secrets Manager, CloudWatch | ~$5 |
| ECR, S3 | ~$2 |
| **Total** | **~$100-125/month** |

To reduce costs: set `ecs_desired_count = 0` when not testing (stops Fargate tasks but keeps infrastructure).
