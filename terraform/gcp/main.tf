# GCP labels must be lowercase: keys/values use [a-z0-9_-], max 63 chars.
# Azure-side tags (CloudOrigin=GCP, Session=AzureArcHybrid) are set by `azcmagent connect --tags`.
locals {
  common_labels = {
    environment    = "demo"
    session        = "azurearchybrid"
    owner          = lower(var.owner)
    cloudorigin    = "gcp"
    managedby      = "terraform"
    costcenter     = lower(var.cost_center)
    expirationdate = lower(var.expiration_date)
  }
  required_apis = [
    "compute.googleapis.com",
    "iap.googleapis.com",
    "oslogin.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each           = toset(local.required_apis)
  project            = var.gcp_project_id
  service            = each.value
  disable_on_destroy = false
}

data "google_compute_image" "ubuntu" {
  family  = var.image_family
  project = var.image_project
}

# ---------------------------------------------------------------- network
resource "google_compute_network" "demo" {
  name                    = "${var.instance_name}-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "demo" {
  name                     = "${var.instance_name}-subnet"
  ip_cidr_range            = var.subnet_cidr
  region                   = var.gcp_region
  network                  = google_compute_network.demo.id
  private_ip_google_access = true
}

# IAP TCP forwarding source range (Google-documented): 35.235.240.0/20
resource "google_compute_firewall" "iap_ssh" {
  name          = "${var.instance_name}-allow-iap-ssh"
  network       = google_compute_network.demo.name
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["arc-demo"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Lab-only shortcut. Not recommended for production.
resource "google_compute_firewall" "ssh_optional" {
  count         = var.allow_public_ssh ? 1 : 0
  name          = "${var.instance_name}-allow-ssh-lab"
  network       = google_compute_network.demo.name
  direction     = "INGRESS"
  source_ranges = [var.ssh_allowed_cidr]
  target_tags   = ["arc-demo"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "egress_https" {
  name               = "${var.instance_name}-allow-egress-web"
  network            = google_compute_network.demo.name
  direction          = "EGRESS"
  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["arc-demo"]
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

# ---------------------------------------------------------------- identity
resource "google_service_account" "vm" {
  account_id   = "${var.instance_name}-sa"
  display_name = "Arc demo VM service account (least privilege)"
}

# Minimum: write logs/metrics only. No project-wide editor role.
resource "google_project_iam_member" "vm_log_writer" {
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vm.email}"
}

resource "google_project_iam_member" "vm_metric_writer" {
  project = var.gcp_project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.vm.email}"
}

# ---------------------------------------------------------------- compute
resource "google_compute_instance" "demo" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.gcp_zone
  tags         = ["arc-demo"]
  labels       = local.common_labels

  boot_disk {
    initialize_params {
      image  = data.google_compute_image.ubuntu.self_link
      size   = 20
      type   = "pd-balanced"
      labels = local.common_labels
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.demo.id
    access_config {} # ephemeral external IP for outbound reachability; no inbound except IAP
  }

  service_account {
    email  = google_service_account.vm.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"] # IAM roles above constrain actual access
  }

  metadata = {
    enable-oslogin = "TRUE"
    # enable-osconfig is only required for the Arc multicloud connector path (preview for GCP). Not needed here.
    user-data = file("${path.module}/../../scripts/cloud-init.yaml")
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  lifecycle {
    ignore_changes = [boot_disk[0].initialize_params[0].image]
  }

  depends_on = [google_project_service.apis]
}
