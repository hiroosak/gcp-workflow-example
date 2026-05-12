# gcp-workflow-example

このリポジトリは、`jaffle_shop` dbt Fusion プロジェクトを Google Cloud 上で実行するためのシンプルな Data Workflow 基盤です。

Codex や他の AI エージェントが作業する場合は、このファイルを最初に読み、既存の `README.md`、`Makefile`、Terraform 設定と矛盾しない変更を行ってください。

## Architecture

- dbt project: `jaffle_shop`
- Local execution: Docker Compose の `dbt` service
- Staging execution: Cloud Scheduler -> Workflows -> Cloud Run Jobs -> BigQuery
- Infrastructure: Terraform under `deploy/terraform`
- Container image: Artifact Registry の `dbt-fusion`
- Default project: env["DBT_BIGQUERY_PROJECT"]
- Default region: `asia-northeast1`
- Default environment: `staging`

Cloud Run Jobs、Workflows、Cloud Scheduler は、Terraform 管理の専用 Service Account を使います。

## Directory Guide

- `jaffle_shop/`: dbt Fusion project。models、macros、seeds、`profiles.yml` を含みます。
- `deploy/terraform/`: Google Cloud resources の Terraform 定義。staging の既定値は `staging.tfvars` です。
- `docker/entrypoint.sh`: container 起動時に `dbt deps` を実行し、その後 dbt command を実行します。
- `Dockerfile`: dbt Fusion を含む実行用 image を作ります。
- `docker-compose.yml`: local で dbt を実行するための Compose 設定です。
- `Makefile`: local 実行、Terraform、image build/push、Workflow/Scheduler 実行の入口です。
- `logs/`: local/generated logs。作業対象として扱わないでください。

## Local Commands

Google Cloud ADC で認証してから local dbt を実行します。

```bash
gcloud auth application-default login
docker compose run --rm dbt
```

よく使う確認コマンド:

```bash
docker compose run --rm dbt dbt --version
docker compose run --rm dbt dbt deps
make local-dbt-version
make local-dbt-deps
```

`docker compose run --rm dbt` は default command として `dbt deps` の後に `dbt build` を実行します。

## Staging Deploy

staging の既定値は以下です。

- Project: `env["DBT_BIGQUERY_PROJECT"]`
- Region: `asia-northeast1`
- BigQuery location: `asia-northeast1`
- dbt dataset: `gcp_workflow_example_staging`
- raw seed dataset: `gcp_workflow_example_staging_raw`
- Image URI: `asia-northeast1-docker.pkg.dev/{ env["DBT_BIGQUERY_PROJECT"] }/gcp-workflow-example/dbt-fusion:staging`
- Workflow: `gcp-workflow-example-staging-dbt`
- Default Scheduler job: `gcp-workflow-example-staging-dbt-daily-all`

Cloud Run Job は、deploy 時点で存在する container image を参照します。初回構築時は次の順序を守ってください。

```bash
make tf-init
make tf-bootstrap
make docker-auth
make image-build
make image-push
make deploy
```

Terraform の確認:

```bash
make tf-fmt
make tf-validate
```

Workflow の手動実行:

```bash
make workflow-run
SELECT='orders+' make workflow-run
```

Scheduler job の手動実行:

```bash
make scheduler-run
SCHEDULER_JOB_NAME=gcp-workflow-example-staging-dbt-daily-orders make scheduler-run
```

## dbt Rules

- `jaffle_shop/` 配下を dbt project として扱います。
- `jaffle_shop/dbt_project.yml` の設定に従い、staging models は view、marts models は table として materialize します。
- seeds は `+schema: raw` で、raw seed 用 dataset に作成されます。
- `jaffle_shop/profiles.yml` は以下の環境変数を参照します。
  - `DBT_TARGET`
  - `DBT_BIGQUERY_PROJECT`
  - `DBT_BIGQUERY_DATASET`
  - `DBT_BIGQUERY_LOCATION`
- local の既定値は Compose/Dockerfile 側で staging 向けに設定されています。
- model、source、seed を変更した場合は、関連する `.yml` の tests/docs も必要に応じて更新してください。

## Terraform Rules

- Terraform 作業ディレクトリは `deploy/terraform` です。
- staging の既定 var-file は `deploy/terraform/staging.tfvars` です。
- `scheduler_jobs` map で Cloud Scheduler job を複数定義できます。各 job は任意の dbt `select` を Workflow に渡せます。
- Workflow は `select` が未指定の場合、`dbt build --target staging` を実行します。
- `select` が指定された場合、Workflow は `dbt build --target staging --select <select>` を Cloud Run Job に渡します。
- production は同じ Terraform files を使い、別 tfvars、別 state backend、別 dataset、別 image tag、別 scheduler 設定で構築する前提です。
- Google Cloud に影響する `terraform apply`、Workflow 実行、Scheduler 実行は、ユーザーの明示指示がある場合だけ実行してください。

## Safety Rules

- secrets、認証情報、service account key、`.env` をコミット対象にしないでください。
- 次の path は生成物または local state として扱い、必要がない限り編集しないでください。
  - `logs/`
  - `target/`
  - `dbt_packages/`
  - `dbt_internal_packages/`
  - `.terraform/`
  - `.env`
- `.dockerignore` は build context に不要な生成物や local state を含めないための設定です。Docker image に必要なファイルを除外しないよう注意してください。
- 既存の `README.md`、`Makefile`、`docker-compose.yml`、`Dockerfile`、`deploy/terraform/*.tf` と矛盾する説明をこのファイルに追加しないでください。
- 外部環境へ影響する操作は、dry-run や validate で確認できる範囲を先に確認してください。

## Public Interfaces

このリポジトリで作業者が意識すべき主な interface は以下です。

- Docker Compose service: `dbt`
- Make targets: `local-dbt-version`, `local-dbt-deps`, `tf-init`, `tf-fmt`, `tf-validate`, `tf-bootstrap`, `docker-auth`, `image-build`, `image-push`, `deploy`, `workflow-run`, `scheduler-run`
- Workflow argument: optional JSON field `select`
- Terraform variable: `scheduler_jobs`

ランタイム API やアプリケーションの型定義はありません。変更時は dbt model contract、Terraform variables、Makefile targets を public interface として扱ってください。
