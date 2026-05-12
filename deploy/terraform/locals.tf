locals {
  name_prefix = "gcp-workflow-example-${var.environment}"
  sa_prefix   = "gdw-${var.environment}"
  image_uri   = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_repo_id}/${var.image_name}:${var.image_tag}"

  common_labels = {
    app         = "gcp-workflow-example"
    environment = var.environment
    managed_by  = "terraform"
  }

  required_services = toset([
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "bigquerystorage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "iam.googleapis.com",
    "run.googleapis.com",
    "serviceusage.googleapis.com",
    "workflows.googleapis.com",
    "workflowexecutions.googleapis.com",
  ])
}
