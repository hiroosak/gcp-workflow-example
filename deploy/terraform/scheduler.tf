resource "google_cloud_scheduler_job" "dbt" {
  for_each = var.scheduler_jobs

  project     = var.project_id
  name        = "${local.name_prefix}-dbt-${replace(each.key, "_", "-")}"
  description = coalesce(each.value.description, "${each.key} ${var.environment} dbt workflow trigger.")
  region      = var.region
  schedule    = each.value.schedule
  time_zone   = each.value.time_zone
  paused      = each.value.paused

  http_target {
    uri         = "https://workflowexecutions.googleapis.com/v1/projects/${var.project_id}/locations/${var.region}/workflows/${google_workflows_workflow.dbt.name}/executions"
    http_method = "POST"
    headers = {
      Content-Type = "application/json"
    }
    body = base64encode(jsonencode({
      argument = jsonencode({
        invocation_source = "scheduler"
        scheduler_job     = each.key
        environment       = var.environment
        select            = each.value.select
      })
    }))

    oauth_token {
      service_account_email = google_service_account.scheduler.email
    }
  }

  attempt_deadline = "320s"

  retry_config {
    retry_count = 1
  }

  depends_on = [
    google_project_iam_member.scheduler_workflows_invoker,
    google_workflows_workflow.dbt,
  ]
}
