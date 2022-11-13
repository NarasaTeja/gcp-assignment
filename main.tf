resource "google_compute_network" "vpc_network" {
  name                    = "vpc-network"
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "private_subnet" {
  name          = "vpc-subnetwork"
  ip_cidr_range = "10.2.0.0/16"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.id
  secondary_ip_range {
    range_name    = "range-update1"
    ip_cidr_range = "192.168.10.0/24"
  }
}


resource "google_compute_firewall" "firewall" {
  name    = "vpc-firewall"
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "3389", "8080", "0-65335"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65335"]
  }

  source_ranges = ["0.0.0.0/0"]

}


resource "google_compute_disk" "es_disk" {
  name  = "es-disk"
  type  = "pd-ssd"
  zone  = "us-central1-a"
  labels = {
    environment = "dev"
  }
  physical_block_size_bytes = 4096
}


resource "google_compute_disk" "redis_disk" {
  name  = "redis-disk"
  type  = "pd-ssd"
  zone  = "us-central1-a"
  labels = {
    environment = "dev"
  }
  physical_block_size_bytes = 4096
}


resource "google_compute_attached_disk" "es_disk" {
  disk     = google_compute_disk.es_disk.id
  instance = google_compute_instance.web_server.id
}

resource "google_compute_attached_disk" "redis_disk" {
  disk     = google_compute_disk.redis_disk.id
  instance = google_compute_instance.web_server.id
}


resource "google_compute_instance" "web_server" {
  name         = "web-instance"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-101-lts"
    }
  }


  network_interface {
    network = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.private_subnet.id
    access_config {
      // Ephemeral public IP
    }
  }

  lifecycle {
    ignore_changes = [attached_disk]
  }

  metadata_startup_script = data.template_file.startup_script.rendered

}

data "template_file" "startup_script" {
  template = file("${path.module}/startup-script.tpl")
    vars = {
    OPENCTI_ADMIN_EMAIL                 = var.OPENCTI_ADMIN_EMAIL
    OPENCTI_ADMIN_PASSWORD              = var.OPENCTI_ADMIN_PASSWORD
    OPENCTI_ADMIN_TOKEN                 = var.OPENCTI_ADMIN_TOKEN
    OPENCTI_BASE_URL                    = var.OPENCTI_BASE_URL
    MINIO_ROOT_USER                     = var.MINIO_ROOT_USER
    MINIO_ROOT_PASSWORD                 = var.MINIO_ROOT_PASSWORD
    RABBITMQ_DEFAULT_USER               = var.RABBITMQ_DEFAULT_USER
    RABBITMQ_DEFAULT_PASS               = var.RABBITMQ_DEFAULT_PASS
    CONNECTOR_EXPORT_FILE_STIX_ID       = var.CONNECTOR_EXPORT_FILE_STIX_ID
    CONNECTOR_EXPORT_FILE_CSV_ID        = var.CONNECTOR_EXPORT_FILE_CSV_ID
    CONNECTOR_EXPORT_FILE_TXT_ID        = var.CONNECTOR_EXPORT_FILE_TXT_ID
    CONNECTOR_IMPORT_FILE_STIX_ID       = var.CONNECTOR_IMPORT_FILE_STIX_ID
    CONNECTOR_IMPORT_DOCUMENT_ID        = var.CONNECTOR_IMPORT_DOCUMENT_ID
    SMTP_HOSTNAME                       = var.SMTP_HOSTNAME
    ELASTIC_MEMORY_SIZE                 = var.ELASTIC_MEMORY_SIZE
  }
}