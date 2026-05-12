FROM debian:bookworm-slim@sha256:67b30a61dc87758f0caf819646104f29ecbda97d920aaf5edc834128ac8493d3

ARG DBT_FUSION_VERSION=2.0.0-preview.175

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        jq \
    && rm -rf /var/lib/apt/lists/*

ENV SHELL=/bin/bash

RUN curl -fsSL https://public.cdn.getdbt.com/fs/install/install.sh -o /tmp/dbt-install.sh \
    && sh /tmp/dbt-install.sh --version "${DBT_FUSION_VERSION}" --to /usr/local/bin --update \
    && rm -f /tmp/dbt-install.sh

RUN groupadd --system --gid 10001 dbt \
    && useradd --system --uid 10001 --gid dbt --create-home --home-dir /home/dbt dbt

ENV PATH="/usr/local/bin:${PATH}" \
    HOME="/home/dbt" \
    XDG_CACHE_HOME="/tmp/dbt-cache" \
    DBT_PROJECT_DIR="/app/jaffle_shop" \
    DBT_TARGET="staging"

WORKDIR /app

COPY docker/entrypoint.sh /usr/local/bin/dbt-entrypoint
COPY --chown=dbt:dbt jaffle_shop /app/jaffle_shop

RUN chmod +x /usr/local/bin/dbt-entrypoint \
    && chown -R dbt:dbt /app

WORKDIR /app/jaffle_shop

USER dbt

ENTRYPOINT ["dbt-entrypoint"]
CMD ["build"]
