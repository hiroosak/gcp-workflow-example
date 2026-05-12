#!/usr/bin/env bash
set -euo pipefail

cd "${DBT_PROJECT_DIR:-/app/jaffle_shop}"
mkdir -p "${XDG_CACHE_HOME:-/tmp/dbt-cache}"

if [[ "${1:-}" == "dbt" ]]; then
  exec "$@"
fi

dbt deps
exec dbt "$@"
