# gcp-workflow-example

Google Cloud 上で dbt Fusion を Cloud Run Jobs と Workflows から実行する、シンプルな Data Workflow 構成です。

※ 一部公開用に内容を変更しているので、疑似コード的なものになります。

# Architecture

- dbt project: `jaffle_shop`
- Local execution: Docker Compose
- Staging execution: Cloud Scheduler -> Workflows -> Cloud Run Jobs -> BigQuery
- Infrastructure: Terraform under `deploy/terraform`
- Container registry: Artifact Registry

Cloud Run Jobs、Workflows、Cloud Scheduler は、それぞれ Terraform 管理の専用 Service Account を使います。

# Quick Start / Setup

# ローカル実行

ローカルで dbt を実行する前に Google Cloud ADC で認証しておく。

```bash
gcloud auth application-default login
docker compose run --rm dbt dbt --version
docker compose run --rm dbt dbt deps
docker compose run --rm dbt
```

コンテナのデフォルトコマンドは `dbt deps` の後に `dbt build` を実行する。

## Google Cloud deploy

### terraform stateの保存先の修正

`deploy/terraform/versions.tf` にある state管理用の bucket指定を修正

### .tfvalueの設置

Google Cloud project ID を環境変数に設定し、Terraform 用の tfvars を example からコピーします。

```bash
export DBT_BIGQUERY_PROJECT=<your-gcp-project-id>
cp deploy/terraform/terraform.tfvars.example deploy/terraform/staging.tfvars
```

`deploy/terraform/staging.tfvars` の内容を適時書き換えをする。

* `project_id` : 自分の Google Cloud project IDにする

## Staging デプロイ

staging のデフォルト設定:

- Project: ENV["DBT_BIGQUERY_PROJECT"]
- Region: `asia-northeast1`
- BigQuery location: `asia-northeast1`
- dbt dataset: `gcp_workflow_example_staging`
- raw seed dataset: `gcp_workflow_example_staging_raw`
- Scheduler jobs:
  - `daily_all`: フル `dbt build`
  - `daily_orders`: `dbt build --select orders+`

未インストールの場合は先に Terraform を入れておく。

```bash
brew install terraform
gcloud storage buckets create gs://<terraform-state-bucket> # terraform state管理用のバケット
make tf-init # terraformの初期化
make tf-bootstrap # 初回のみ: serviceの開始. Artifact Registry の作成
make docker-auth # docker pushの設定
make image-build # docker imageのpush
make image-push
make deploy
```

Workflow の手動実行。`SELECT` は省略可能で、省略した場合は `dbt build --target staging` がフルで走る。

```bash
make workflow-run
SELECT='orders+' make workflow-run
```

Scheduler job の手動トリガー:

```bash
make scheduler-run
SCHEDULER_JOB_NAME=gcp-workflow-example-staging-dbt-daily-orders make scheduler-run
```

## Production

同じ Terraform ファイルを使い、別の tfvars ファイル・dataset 名・image タグ・scheduler 設定・state backend で構築する。
