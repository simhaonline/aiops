# PostgreSQL, pgvector and TimescaleDB

The SaaS data plane uses PostgreSQL as its system of record, `pgvector` for
semantic retrieval, and TimescaleDB for model, job, and infrastructure events.
The migrations are applied in order: [001_initial.sql](migrations/001_initial.sql)
creates the tenant/project foundation and [002_workspace_records.sql](migrations/002_workspace_records.sql)
adds persisted workspace records, jobs, approvals, and audit events, and
[003_worker_lifecycle.sql](migrations/003_worker_lifecycle.sql) adds claim,
heartbeat, retry, and idempotency fields.

Run migrations with a database-owner role during deployment, then configure
the API with a separate least-privilege role:

```sh
export AIOPS_DATABASE_URL='postgresql://aiops_api:REDACTED@db/aiops'
export AIOPS_DATABASE_SSL=require
psql "$AIOPS_DATABASE_URL" -f dashboard/database/migrations/001_initial.sql
psql "$AIOPS_DATABASE_URL" -f dashboard/database/migrations/002_workspace_records.sql
psql "$AIOPS_DATABASE_URL" -f dashboard/database/migrations/003_worker_lifecycle.sql
```

`AIOPS_DATABASE_URL` is optional for the local/read-only dashboard. When it is
absent, `/api/health` reports `configured: false`; no local database is created
implicitly. Production deployments should use a managed PostgreSQL-compatible
service or a pinned PostgreSQL image with both extensions installed.

Every application transaction must set `SET LOCAL app.tenant_id = '<uuid>'`.
The API does this through `DatabaseService.withTenant`; set `AIOPS_TENANT_ID`
to the tenant UUID and send the server-only `x-aiops-dashboard-token` header.
CRUD routes reject requests without both values. `AIOPS_DASHBOARD_ROLE` controls
the development actor role (`viewer`, `operator`, `admin`, or `owner`).
Row-level security policies intentionally return no rows when tenant context is
missing. Large media remains in tenant-scoped object storage; only metadata and
content hashes belong in PostgreSQL.

Run the API and worker as separate processes:

```sh
npm run start -w @aiops/api
npm run worker -w @aiops/api
```

Workers claim jobs with PostgreSQL row locks, update heartbeats, retry transient
failures with exponential backoff, and mark terminal failures with a safe error
code. Repository checkout uses `git` without a shell; knowledge embeddings and
media output require their configured providers or explicit development flags.
