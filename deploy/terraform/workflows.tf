resource "google_workflows_workflow" "dbt" {
  project             = var.project_id
  name                = "${local.name_prefix}-dbt"
  region              = var.region
  description         = "Runs the ${var.environment} dbt Cloud Run Job."
  service_account     = google_service_account.workflows.email
  deletion_protection = false
  labels              = local.common_labels

  source_contents = <<-YAML
  main:
    params: [args]
    steps:
      - init:
          assign:
            - project_id: "${var.project_id}"
            - region: "${var.region}"
            - job_name: "${google_cloud_run_v2_job.dbt.name}"
            - workflow_args: {}
            - select: ""
            - dbt_args:
                - "build"
                - "--target"
                - "${var.environment}"
      - load_args:
          switch:
            - condition: $${args != null}
              assign:
                - workflow_args: $${args}
      - read_select:
          assign:
            - select: $${default(map.get(workflow_args, "select"), "")}
            - payload: $${json.encode_to_string(workflow_args)}
      - append_select:
          switch:
            - condition: $${select != ""}
              assign:
                - dbt_args: $${list.concat(list.concat(dbt_args, "--select"), select)}
      - run_dbt_job:
          call: googleapis.run.v1.namespaces.jobs.run
          args:
            name: $${"namespaces/" + project_id + "/jobs/" + job_name}
            location: $${region}
            body:
              overrides:
                containerOverrides:
                  - name: "dbt"
                    args: $${dbt_args}
                    env:
                      - name: "WORKFLOW_EXECUTION_ARGUMENT"
                        value: $${payload}
          result: job_execution
      - finish:
          return: $${job_execution}
  YAML

  depends_on = [
    google_cloud_run_v2_job.dbt,
    google_cloud_run_v2_job_iam_member.workflows_dbt_job_executor,
    google_project_iam_member.workflows_cloud_run_viewer,
    google_service_account_iam_member.workflows_dbt_job_service_account_user,
    google_project_service_identity.workflows,
  ]
}
