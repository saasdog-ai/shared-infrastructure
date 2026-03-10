# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------

locals {
  name_prefix = "${var.company_prefix}-shared"

  common_labels = {
    project     = "shared-infrastructure"
    environment = var.environment
    managed-by  = "terraform"
  }
}

# -----------------------------------------------------------------------------
# Enable Required APIs
# -----------------------------------------------------------------------------

resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "vpcaccess.googleapis.com",
    "secretmanager.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "pubsub.googleapis.com",
    "cloudkms.googleapis.com",
  ])

  project = var.gcp_project_id
  service = each.value

  disable_on_destroy = false
}

# -----------------------------------------------------------------------------
# VPC Network
# -----------------------------------------------------------------------------

resource "google_compute_network" "main" {
  count = var.create_vpc ? 1 : 0

  name                    = "${local.name_prefix}-vpc-${var.environment}"
  auto_create_subnetworks = false
  project                 = var.gcp_project_id

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# Subnets
# -----------------------------------------------------------------------------

resource "google_compute_subnetwork" "public" {
  count = var.create_vpc ? 1 : 0

  name          = "${local.name_prefix}-public-${var.environment}"
  ip_cidr_range = var.public_subnet_cidr
  region        = var.gcp_region
  network       = google_compute_network.main[0].id

  purpose = "PRIVATE"
}

resource "google_compute_subnetwork" "private" {
  count = var.create_vpc ? 1 : 0

  name                     = "${local.name_prefix}-private-${var.environment}"
  ip_cidr_range            = var.private_subnet_cidr
  region                   = var.gcp_region
  network                  = google_compute_network.main[0].id
  private_ip_google_access = true

  purpose = "PRIVATE"
}

# -----------------------------------------------------------------------------
# Cloud NAT (for private subnet internet access)
# -----------------------------------------------------------------------------

resource "google_compute_router" "main" {
  count = var.create_vpc && var.enable_nat ? 1 : 0

  name    = "${local.name_prefix}-router-${var.environment}"
  region  = var.gcp_region
  network = google_compute_network.main[0].id
}

resource "google_compute_router_nat" "main" {
  count = var.create_vpc && var.enable_nat ? 1 : 0

  name                               = "${local.name_prefix}-nat-${var.environment}"
  router                             = google_compute_router.main[0].name
  region                             = var.gcp_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# -----------------------------------------------------------------------------
# Firewall Rules
# -----------------------------------------------------------------------------

resource "google_compute_firewall" "allow_internal" {
  count = var.create_vpc ? 1 : 0

  name    = "${local.name_prefix}-allow-internal-${var.environment}"
  network = google_compute_network.main[0].name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.public_subnet_cidr, var.private_subnet_cidr]
}

resource "google_compute_firewall" "allow_health_checks" {
  count = var.create_vpc ? 1 : 0

  name    = "${local.name_prefix}-allow-health-checks-${var.environment}"
  network = google_compute_network.main[0].name

  allow {
    protocol = "tcp"
  }

  # GCP health check IP ranges
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
}

# -----------------------------------------------------------------------------
# Private Service Networking (for Cloud SQL private IP)
# -----------------------------------------------------------------------------

resource "google_compute_global_address" "private_services" {
  count = var.create_vpc && var.create_cloud_sql ? 1 : 0

  name          = "${local.name_prefix}-private-services-${var.environment}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main[0].id

  depends_on = [google_project_service.apis]
}

resource "google_service_networking_connection" "private_services" {
  count = var.create_vpc && var.create_cloud_sql ? 1 : 0

  network                 = google_compute_network.main[0].id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services[0].name]

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# VPC Connector (for Cloud Run → VPC connectivity)
# -----------------------------------------------------------------------------

resource "google_vpc_access_connector" "main" {
  count = var.create_vpc ? 1 : 0

  name          = "${local.name_prefix}-conn-${var.environment}"
  region        = var.gcp_region
  ip_cidr_range = var.vpc_connector_cidr
  network       = google_compute_network.main[0].name

  min_instances = 2
  max_instances = 3

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# Cloud SQL PostgreSQL
# -----------------------------------------------------------------------------

resource "random_password" "cloud_sql_master" {
  count = var.create_cloud_sql ? 1 : 0

  length  = 32
  special = false
}

resource "google_secret_manager_secret" "cloud_sql_master_password" {
  count = var.create_cloud_sql ? 1 : 0

  secret_id = "${local.name_prefix}-cloud-sql-master-password-${var.environment}"

  replication {
    auto {}
  }

  labels = local.common_labels

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "cloud_sql_master_password" {
  count = var.create_cloud_sql ? 1 : 0

  secret      = google_secret_manager_secret.cloud_sql_master_password[0].id
  secret_data = random_password.cloud_sql_master[0].result
}

resource "google_sql_database_instance" "main" {
  count = var.create_cloud_sql ? 1 : 0

  name                = "${local.name_prefix}-sql-${var.environment}"
  database_version    = var.cloud_sql_database_version
  region              = var.gcp_region
  deletion_protection = var.cloud_sql_deletion_protection

  settings {
    tier              = var.cloud_sql_tier
    disk_size         = var.cloud_sql_disk_size
    disk_type         = "PD_SSD"
    disk_autoresize   = true
    availability_type = var.cloud_sql_ha ? "REGIONAL" : "ZONAL"

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.main[0].id
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = var.cloud_sql_ha
    }

    maintenance_window {
      day  = 1 # Monday
      hour = 4
    }

    database_flags {
      name  = "max_connections"
      value = "100"
    }
  }

  depends_on = [google_service_networking_connection.private_services]
}

resource "google_sql_database" "main" {
  count = var.create_cloud_sql ? 1 : 0

  name     = var.cloud_sql_database_name
  instance = google_sql_database_instance.main[0].name
}

resource "google_sql_user" "master" {
  count = var.create_cloud_sql ? 1 : 0

  name     = "postgres"
  instance = google_sql_database_instance.main[0].name
  password = random_password.cloud_sql_master[0].result
}
