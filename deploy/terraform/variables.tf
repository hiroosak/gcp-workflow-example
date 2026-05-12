variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Region for Artifact Registry, Cloud Run Jobs, Workflows, and Cloud Scheduler."
  type        = string
  default     = "asia-northeast1"
}

variable "bigquery_location" {
  description = "BigQuery dataset location."
  type        = string
  default     = "asia-northeast1"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "staging"
}

variable "dataset_id" {
  description = "BigQuery dataset for dbt staging and marts models."
  type        = string
  default     = "gcp_workflow_example_staging"
}

variable "raw_dataset_id" {
  description = "BigQuery dataset for dbt seed tables."
  type        = string
  default     = "gcp_workflow_example_staging_raw"
}

variable "artifact_repo_id" {
  description = "Artifact Registry Docker repository ID."
  type        = string
  default     = "gcp-workflow-example"
}

variable "image_name" {
  description = "Container image name in Artifact Registry."
  type        = string
  default     = "dbt-fusion"
}

variable "image_tag" {
  description = "Container image tag deployed to Cloud Run Jobs."
  type        = string
  default     = "staging"
}

variable "scheduler_jobs" {
  description = "Cloud Scheduler jobs that invoke the dbt workflow. Each job can pass a dbt select expression."
  type = map(object({
    schedule    = string
    time_zone   = optional(string, "Asia/Tokyo")
    paused      = optional(bool, false)
    select      = optional(string)
    description = optional(string)
  }))
  default = {
    daily_all = {
      schedule    = "0 9 * * *"
      time_zone   = "Asia/Tokyo"
      paused      = false
      select      = null
      description = "Daily full dbt build"
    }
  }
}
