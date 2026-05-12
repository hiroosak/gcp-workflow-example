output "artifact_repository" {
  description = "Artifact Registry repository name."
  value       = google_artifact_registry_repository.dbt.name
}

output "image_uri" {
  description = "Container image URI expected by the Cloud Run Job."
  value       = local.image_uri
}

output "cloud_run_job_name" {
  description = "Cloud Run Job name."
  value       = google_cloud_run_v2_job.dbt.name
}

output "workflow_name" {
  description = "Workflows workflow name."
  value       = google_workflows_workflow.dbt.name
}

output "scheduler_job_names" {
  description = "Cloud Scheduler job names keyed by scheduler_jobs key."
  value       = { for key, job in google_cloud_scheduler_job.dbt : key => job.name }
}
