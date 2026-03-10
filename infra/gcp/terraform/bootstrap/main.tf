# Bootstrap: Terraform State Infrastructure for GCP
# Run ONCE to create the GCS bucket for state storage.
# Usage:
#   cd bootstrap
#   terraform init
#   terraform apply -var="company_prefix=mycompany" -var="gcp_project_id=my-project"

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

variable "company_prefix" {
  description = "Company prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
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

locals {
  bucket_name = "${var.company_prefix}-shared-infra-tfstate-${var.environment}"
}

resource "google_storage_bucket" "terraform_state" {
  name          = local.bucket_name
  location      = var.gcp_region
  force_destroy = false

  versioning {
    enabled = true
  }

  uniform_bucket_level_access = true

  labels = {
    project     = "shared-infrastructure"
    environment = var.environment
    managed-by  = "terraform-bootstrap"
    company     = var.company_prefix
  }

  lifecycle {
    prevent_destroy = true
  }
}

output "state_bucket_name" {
  description = "Name of the GCS bucket for Terraform state"
  value       = google_storage_bucket.terraform_state.name
}

output "backend_config" {
  description = "Backend configuration to add to versions.tf"
  value       = <<-EOT
    backend "gcs" {
      bucket = "${local.bucket_name}"
      prefix = "terraform/state"
    }
  EOT
}
