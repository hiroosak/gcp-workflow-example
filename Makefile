TF_DIR ?= deploy/terraform
TF_VARS ?= staging.tfvars

PROJECT_ID ?= ${DBT_BIGQUERY_PROJECT}
REGION ?= asia-northeast1
ARTIFACT_REPO_ID ?= gcp-workflow-example
IMAGE_NAME ?= dbt-fusion
IMAGE_TAG ?= staging
IMAGE_URI ?= $(REGION)-docker.pkg.dev/$(PROJECT_ID)/$(ARTIFACT_REPO_ID)/$(IMAGE_NAME):$(IMAGE_TAG)
IMAGE_PLATFORM ?= linux/amd64

WORKFLOW_NAME ?= gcp-workflow-example-staging-dbt
SCHEDULER_JOB_NAME ?= gcp-workflow-example-staging-dbt-daily-all

.PHONY: tf-init tf-fmt tf-validate tf-bootstrap image-build image-push docker-auth deploy workflow-run scheduler-run local-dbt-version local-dbt-deps

tf-init:
	terraform -chdir=$(TF_DIR) init

tf-fmt:
	terraform -chdir=$(TF_DIR) fmt

tf-validate:
	terraform -chdir=$(TF_DIR) validate

tf-bootstrap:
	terraform -chdir=$(TF_DIR) apply -var-file=$(TF_VARS) -target=google_project_service.required -target=google_artifact_registry_repository.dbt

docker-auth:
	gcloud auth configure-docker $(REGION)-docker.pkg.dev

image-build:
	docker build --platform $(IMAGE_PLATFORM) -t $(IMAGE_URI) .

image-push:
	docker push $(IMAGE_URI)

deploy:
	terraform -chdir=$(TF_DIR) apply -var-file=$(TF_VARS)

deploy-plan:
	terraform -chdir=$(TF_DIR) plan -var-file=$(TF_VARS)


workflow-run:
	@if [ -n "$(SELECT)" ]; then \
		gcloud workflows run $(WORKFLOW_NAME) --location=$(REGION) --data='{"select":"$(SELECT)"}'; \
	else \
		gcloud workflows run $(WORKFLOW_NAME) --location=$(REGION) --data='{}'; \
	fi

scheduler-run:
	gcloud scheduler jobs run $(SCHEDULER_JOB_NAME) --location=$(REGION)

local-dbt-version:
	docker compose run --rm dbt dbt --version

local-dbt-deps:
	docker compose run --rm dbt dbt deps
