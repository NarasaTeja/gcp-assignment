terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.41.0"
    }
  }
}

provider "google" {
  project = "scenic-patrol-298711" # Update the project name
  region  = "us-central1"
  zone    = "us-central1-a"
}

