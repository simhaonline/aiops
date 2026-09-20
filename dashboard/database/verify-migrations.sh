#!/usr/bin/env bash
set -Eeuo pipefail
: "${AIOPS_DATABASE_URL:?Set AIOPS_DATABASE_URL to a clean PostgreSQL database}"
for migration in "$(dirname "$0")"/migrations/*.sql; do
  echo "Applying ${migration##*/}"
  psql "$AIOPS_DATABASE_URL" -v ON_ERROR_STOP=1 -f "$migration" >/dev/null
done
psql "$AIOPS_DATABASE_URL" -v ON_ERROR_STOP=1 -Atc "SELECT count(*) FROM information_schema.tables WHERE table_schema='app'; SELECT count(*) FROM pg_indexes WHERE schemaname='app' AND indexname='jobs_claim_idx';"
