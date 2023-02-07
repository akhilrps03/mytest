provider "google" {
  project = "akhilesh-new"
  region  = "asia-south1"
  zone    = "asia-south1-c"
}
resource "random_id" "bucket_prefix" {
  byte_length = 8
}

resource "google_storage_bucket" "bucket" {
  name          = "${random_id.bucket_prefix.hex}-bucket-tfstate"
  force_destroy = false
  location      = "asia-south1"
  storage_class = "STANDARD"
  versioning {
    enabled = true
  }
}
terraform {
 backend "gcs" {
   bucket  = "a8e9020a381562b8-bucket-tfstate"
   prefix  = "terraform/state"
 }
}
resource "google_compute_network" "vpc" {
  name                    = "custom-network"
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "subnet" {
  name          = "custom-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "asia-south1"
  network       = google_compute_network.vpc.id
}

resource "google_compute_instance" "instance" {
  name         = "test-vm"
  machine_type = "e2-micro"
  zone         = "asia-south1-c"
  tags         = ["ssh"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  # Install Flask
  metadata_startup_script = "sudo apt-get update; sudo apt-get install -y nginx"

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id

    access_config {
      # Include this section to give the VM an external IP address
    }
  }
}
resource "google_compute_firewall" "ssh" {
  name = "allow-ssh"
  allow {
    ports    = ["22"]
    protocol = "tcp"
  }
  direction     = "INGRESS"
  network       = google_compute_network.vpc.id
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh"]
}
resource "google_compute_firewall" "nginx" {
  name    = "app-firewall"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = ["0.0.0.0/0"]
}
output "Web-server-URL" {
 value = join("",["http://",google_compute_instance.instance.network_interface.0.access_config.0.nat_ip,":80"])
}
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}
resource "google_service_networking_connection" "default" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}
resource "google_sql_database_instance" "instance" {
  name             = "private-ip-sql-instance"
  region           = "asia-south1"
  database_version = "MYSQL_8_0"

  depends_on = [google_service_networking_connection.default]

  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled    = "false"
      private_network = google_compute_network.vpc.id
    }
  }
  deletion_protection = false # set to true to prevent destruction of the resource
}
resource "google_compute_network_peering_routes_config" "peering_routes" {
  peering              = google_service_networking_connection.default.peering
  network              = google_compute_network.vpc.name
  import_custom_routes = true
  export_custom_routes = true
}
