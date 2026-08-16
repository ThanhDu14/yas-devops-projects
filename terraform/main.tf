# ==========================================
# 1. Enable Google APIs
# ==========================================
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "artifactregistry.googleapis.com",
    "iap.googleapis.com"
  ])
  service            = each.key
  disable_on_destroy = false
}

# ==========================================
# 2. Create custom VPC and Subnets
# ==========================================
resource "google_compute_network" "custom_vpc" {
  depends_on              = [google_project_service.apis]
  name                    = "yas-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public_subnet" {
  name          = "yas-public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.custom_vpc.id
}

resource "google_compute_subnetwork" "private_subnet" {
  name                     = "yas-private-subnet"
  ip_cidr_range            = "10.0.2.0/24"
  region                   = var.region
  network                  = google_compute_network.custom_vpc.id
  private_ip_google_access = true
}

# ==========================================
# 3. Cloud Router & Cloud NAT
# ==========================================
resource "google_compute_router" "nat_router" {
  name    = "yas-nat-router"
  region  = var.region
  network = google_compute_network.custom_vpc.id
}

resource "google_compute_router_nat" "cloud_nat" {
  name                               = "yas-cloud-nat"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# ==========================================
# 4. Firewall Rules
# ==========================================
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "yas-allow-iap-ssh"
  network = google_compute_network.custom_vpc.id
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["yas-secure-server"]
}

resource "google_compute_firewall" "allow_internal" {
  name    = "yas-allow-internal"
  network = google_compute_network.custom_vpc.id
  allow {
    protocol = "all"
  }
  source_ranges = ["10.0.0.0/16"]
}

resource "google_compute_firewall" "allow_health_check" {
  name    = "yas-allow-health-check"
  network = google_compute_network.custom_vpc.id
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["yas-secure-server"]
}

# ==========================================
# 5. Service Account
# ==========================================
resource "google_service_account" "vm_sa" {
  account_id   = "yas-vm-sa"
  display_name = "Service Account for YAS Compute VM"
}

resource "google_project_iam_member" "artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.vm_sa.email}"
}

# ==========================================
# 6. Artifact Registry
# ==========================================
resource "google_artifact_registry_repository" "yas_repo" {
  depends_on    = [google_project_service.apis]
  location      = var.region
  repository_id = "yas-docker-repo"
  description   = "Docker repository for YAS microservices"
  format        = "DOCKER"
}

# ==========================================
# 7. Backend Auto-Scaling (Template + MIG + Autoscaler)
# ==========================================
resource "google_compute_health_check" "yas_health_check" {
  name               = "yas-backend-health-check"
  check_interval_sec = 10
  timeout_sec        = 5
  unhealthy_threshold = 3

  tcp_health_check {
    port = 80
  }
}

resource "google_compute_instance_template" "yas_template" {
  name_prefix  = "yas-template-"
  machine_type = var.machine_type
  region       = var.region

  tags = ["yas-secure-server"]

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2204-lts"
    auto_delete  = true
    boot         = true
    disk_size_gb = 50
    disk_type    = "pd-ssd"
  }

  network_interface {
    network    = google_compute_network.custom_vpc.id
    subnetwork = google_compute_subnetwork.private_subnet.id
  }

  service_account {
    email  = google_service_account.vm_sa.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = file("${path.module}/scripts/startup.sh")

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_instance_group_manager" "yas_mig" {
  name               = "yas-mig"
  region             = var.region
  base_instance_name = "yas-backend"

  distribution_policy_zones = ["${var.region}-a", "${var.region}-b"]
  target_size               = 1

  version {
    instance_template = google_compute_instance_template.yas_template.id
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.yas_health_check.id
    initial_delay_sec = 900
  }

  named_port {
    name = "http"
    port = 80
  }

  lifecycle {
    ignore_changes = [target_size]
  }
}

resource "google_compute_region_autoscaler" "yas_autoscaler" {
  name   = "yas-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.yas_mig.id

  autoscaling_policy {
    min_replicas    = 1
    max_replicas    = 3
    cooldown_period = 60

    cpu_utilization {
      target = 0.6
    }
  }
}

# ==========================================
# 8. Load Balancer (route tat ca traffic ve VM)
# ==========================================
resource "google_compute_backend_service" "backend_service" {
  name          = "yas-backend-service"
  protocol      = "HTTP"
  port_name     = "http"
  timeout_sec   = 30
  health_checks = [google_compute_health_check.yas_health_check.id]

  backend {
    group = google_compute_region_instance_group_manager.yas_mig.instance_group
  }
}

resource "google_compute_url_map" "yas_url_map" {
  name            = "yas-global-url-map"
  default_service = google_compute_backend_service.backend_service.id
}

resource "google_compute_target_http_proxy" "yas_http_proxy" {
  name    = "yas-target-http-proxy"
  url_map = google_compute_url_map.yas_url_map.id
}

resource "google_compute_global_forwarding_rule" "yas_forwarding_rule" {
  name        = "yas-global-forwarding-rule"
  target      = google_compute_target_http_proxy.yas_http_proxy.id
  port_range  = "80"
  ip_protocol = "TCP"
}