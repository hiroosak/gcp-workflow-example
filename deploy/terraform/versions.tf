terraform {
  required_version = ">= 1.15.0"

  backend "gcs" {
    bucket = "<gcp-workflow-example-tfstate>"
    prefix = "staging"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.37.0, < 8.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 6.37.0, < 8.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}
