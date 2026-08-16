# PostgreSQL, pgvector and TimescaleDB

The SaaS data plane uses PostgreSQL as its system of record, `pgvector` for
semantic retrieval, and TimescaleDB for model, job, and infrastructure events.
The first migration is [001_initial.sql](migrations/001_initial.sql).

Run migrations with a database-owner role during deployment, then configure
the API with a separate least-privilege role:

```sh
export AIOPS_DATABASE_URL='postgresql://aiops_api:REDACTED@db/aiops'
export AIOPS_DATABASE_SSL=require
psql "$AIOPS_DATABASE_URL" -f dashboard/database/migrations/001_initial.sql
```

`AIOPS_DATABASE_URL` is optional for the local/read-only dashboard. When it is
absent, `/api/health` reports `configured: false`; no local database is created
implicitly. Production deployments should use a managed PostgreSQL-compatible
service or a pinned PostgreSQL image with both extensions installed.

Every application transaction must set `SET LOCAL app.tenant_id = '<uuid>'`.
Row-level security policies intentionally return no rows when tenant context is
missing. Large media remains in tenant-scoped object storage; only metadata and
content hashes belong in PostgreSQL.

Q-AI request/evidence persistence is not enabled by this migration. The Q-AI
module currently returns versioned decision metadata in-process; durable
outcomes and calibration data require authenticated tenant transactions first.
