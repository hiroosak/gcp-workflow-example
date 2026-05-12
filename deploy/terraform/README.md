# Terraform

このディレクトリでは、`gcp-workflow-example` の staging 用 Google Cloud リソースを管理します。

## Resources

- 必要な Google Cloud API
- Artifact Registry の Docker リポジトリ
- dbt モデルと raw seed 用の BigQuery dataset
- dbt Fusion を実行する Cloud Run Job
- 手動実行・定期実行の入口になる Workflows
- `select` ごとに複数定義できる Cloud Scheduler
- Service Account と IAM binding

## Workflow Arguments

Workflow は dbt target を `staging` に固定し、任意の `select` だけを受け取ります。
`select` が未指定の場合は、全量の `dbt build --target staging` を実行します。

```bash
# 全量 build
gcloud workflows run gcp-workflow-example-staging-dbt \
  --location=asia-northeast1 \
  --data='{}'

# select を指定した build
gcloud workflows run gcp-workflow-example-staging-dbt \
  --location=asia-northeast1 \
  --data='{"select":"orders+"}'
```

Scheduler は `scheduler_jobs` map で複数定義できます。

```hcl
scheduler_jobs = {
  daily_all = {
    schedule    = "0 9 * * *"
    time_zone   = "Asia/Tokyo"
    paused      = false
    select      = null
    description = "Daily full dbt build"
  }

  daily_orders = {
    schedule    = "30 9 * * *"
    time_zone   = "Asia/Tokyo"
    paused      = false
    select      = "orders+"
    description = "Daily orders lineage build"
  }
}
```

## Bootstrap Flow

Cloud Run Job は、事前に存在するコンテナイメージを参照します。
そのため、まず API と Artifact Registry だけを作成し、イメージを push してから全体を apply します。

Terraform state は GCS backend で管理します。初回だけ backend 用 bucket を Terraform の外で作成し、local state がある場合は GCS に移行します。

```bash
# backend 用 bucket を作成します。
gcloud storage buckets create gs://${DBT_BIGQUERY_PROJECT}-gcp-workflow-example-tfstate \
  --project=${DBT_BIGQUERY_PROJECT} \
  --location=asia-northeast1 \
  --uniform-bucket-level-access

# state 復旧のため、bucket versioning を有効化します。
gcloud storage buckets update gs://${DBT_BIGQUERY_PROJECT} -gcp-workflow-example-tfstate --versioning

# local state から GCS backend に移行します。
terraform init -migrate-state

# state object と Terraform state の内容を確認します。
gcloud storage ls gs://${DBT_BIGQUERY_PROJECT}-gcp-workflow-example-tfstate/staging/
terraform state list
```

```bash
# Terraform を初期化し、Google provider をダウンロードします。
terraform init

# 先に必要な API と Artifact Registry リポジトリだけを作成します。
# Cloud Run Job はイメージが存在してから作る必要があるため、この時点ではまだ apply しません。
terraform apply -var-file=staging.tfvars -target=google_project_service.required -target=google_artifact_registry_repository.dbt

# asia-northeast1 の Artifact Registry に Docker で push できるよう認証設定を行います。
gcloud auth configure-docker asia-northeast1-docker.pkg.dev

# リポジトリルートを build context にして、staging 用の dbt Fusion イメージをビルドします。
docker build -t asia-northeast1-docker.pkg.dev/${DBT_BIGQUERY_PROJECT}/gcp-workflow-example/dbt-fusion:staging ../..

# Cloud Run Job がデプロイ時に取得できるよう、Artifact Registry にイメージを push します。
docker push asia-northeast1-docker.pkg.dev/${DBT_BIGQUERY_PROJECT}/gcp-workflow-example/dbt-fusion:staging

# BigQuery dataset、Service Account、IAM、Cloud Run Job、Workflows、Scheduler をまとめて apply します。
terraform apply -var-file=staging.tfvars
```
