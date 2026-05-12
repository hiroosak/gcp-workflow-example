resource "google_project_service" "required" {
  for_each = local.required_services

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "dbt" {
  project       = var.project_id
  location      = var.region
  repository_id = var.artifact_repo_id
  description   = "Docker images for ${local.name_prefix}"
  format        = "DOCKER"
  labels        = local.common_labels

  depends_on = [google_project_service.required]
}

resource "google_bigquery_dataset" "dbt" {
  project                    = var.project_id
  dataset_id                 = var.dataset_id
  friendly_name              = "${local.name_prefix} dbt models"
  description                = "dbt staging and marts dataset for ${local.name_prefix}."
  location                   = var.bigquery_location
  delete_contents_on_destroy = false
  labels                     = local.common_labels

  depends_on = [google_project_service.required]
}

resource "google_bigquery_dataset" "raw" {
  project                    = var.project_id
  dataset_id                 = var.raw_dataset_id
  friendly_name              = "${local.name_prefix} raw seeds"
  description                = "Raw seed dataset for ${local.name_prefix}."
  location                   = var.bigquery_location
  delete_contents_on_destroy = false
  labels                     = local.common_labels

  depends_on = [google_project_service.required]
}

resource "google_service_account" "dbt_job" {
  project      = var.project_id
  account_id   = "${local.sa_prefix}-dbt"
  display_name = "dbt Cloud Run Job (${var.environment})"

  depends_on = [google_project_service.required]
}

resource "google_service_account" "workflows" {
  project      = var.project_id
  account_id   = "${local.sa_prefix}-wf"
  display_name = "Workflow runner (${var.environment})"

  depends_on = [google_project_service.required]
}

resource "google_service_account" "scheduler" {
  project      = var.project_id
  account_id   = "${local.sa_prefix}-sch"
  display_name = "Workflow scheduler (${var.environment})"

  depends_on = [google_project_service.required]
}

resource "google_project_iam_member" "dbt_job_bigquery_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.dbt_job.email}"
}

resource "google_project_iam_member" "dbt_job_bigquery_read_session_user" {
  project = var.project_id
  role    = "roles/bigquery.readSessionUser"
  member  = "serviceAccount:${google_service_account.dbt_job.email}"
}

resource "google_bigquery_dataset_iam_member" "dbt_job_dataset_editor" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.dbt.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.dbt_job.email}"
}

resource "google_bigquery_dataset_iam_member" "dbt_job_raw_dataset_editor" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.raw.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.dbt_job.email}"
}

resource "google_artifact_registry_repository_iam_member" "dbt_job_artifact_reader" {
  project    = var.project_id
  location   = google_artifact_registry_repository.dbt.location
  repository = google_artifact_registry_repository.dbt.repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.dbt_job.email}"
}

resource "google_project_iam_member" "scheduler_workflows_invoker" {
  project = var.project_id
  role    = "roles/workflows.invoker"
  member  = "serviceAccount:${google_service_account.scheduler.email}"
}

resource "google_project_iam_member" "workflows_cloud_run_viewer" {
  project = var.project_id
  role    = "roles/run.viewer"
  member  = "serviceAccount:${google_service_account.workflows.email}"
}

resource "google_project_service_identity" "workflows" {
  provider = google-beta

  project = var.project_id
  service = "workflows.googleapis.com"

  depends_on = [google_project_service.required["workflows.googleapis.com"]]
}

resource "google_cloud_run_v2_job" "dbt" {
  project             = var.project_id
  name                = "${local.name_prefix}-dbt"
  location            = var.region
  deletion_protection = false
  labels              = local.common_labels

  template {
    task_count  = 1
    parallelism = 1

    template {
      service_account = google_service_account.dbt_job.email
      timeout         = "3600s"
      max_retries     = 0

      containers {
        name  = "dbt"
        image = local.image_uri

        env {
          name  = "DBT_TARGET"
          value = var.environment
        }

        env {
          name  = "DBT_BIGQUERY_PROJECT"
          value = var.project_id
        }

        env {
          name  = "DBT_BIGQUERY_DATASET"
          value = var.dataset_id
        }

        env {
          name  = "DBT_BIGQUERY_LOCATION"
          value = var.bigquery_location
        }

        resources {
          limits = {
            cpu    = "1"
            memory = "1Gi"
          }
        }
      }
    }
  }

  depends_on = [
    google_artifact_registry_repository.dbt,
    google_bigquery_dataset_iam_member.dbt_job_dataset_editor,
    google_bigquery_dataset_iam_member.dbt_job_raw_dataset_editor,
    google_project_iam_member.dbt_job_bigquery_job_user,
  ]
}

resource "google_cloud_run_v2_job_iam_member" "workflows_dbt_job_executor" {
  project  = google_cloud_run_v2_job.dbt.project
  location = google_cloud_run_v2_job.dbt.location
  name     = google_cloud_run_v2_job.dbt.name
  role     = "roles/run.jobsExecutorWithOverrides"
  member   = "serviceAccount:${google_service_account.workflows.email}"
}

resource "google_service_account_iam_member" "workflows_dbt_job_service_account_user" {
  service_account_id = google_service_account.dbt_job.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.workflows.email}"
}
