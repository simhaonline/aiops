# SIMHA AiOps SaaS architecture

This document defines the first SaaS foundation while preserving the existing
self-hosted CLI. The control plane is additive: tenant requests never gain
access to the host Docker socket or the privileged manager broker.

## Boundaries

| Plane | Responsibility | Data boundary |
|---|---|---|
| Control plane | identity, tenants, memberships, plans, quotas, audit policy | PostgreSQL `app` schema |
| Data plane | projects, conversations, knowledge retrieval, model routing | tenant-scoped PostgreSQL rows and object-storage prefixes |
| Worker plane | crawling, parsing, embeddings, transcription, translation, media jobs | queue messages carry an explicit tenant ID |
| Telemetry plane | latency, tokens, provider, cost, job and infrastructure events | TimescaleDB `telemetry` schema |
| Self-hosted host plane | existing managers and local operations | remains outside SaaS tenant execution |

## Database decision

PostgreSQL remains the transactional source of truth. pgvector is used only
for embedding-bearing knowledge chunks, while TimescaleDB hypertables are used
for append-heavy time-series events. Media and large source files belong in
tenant-scoped S3-compatible object storage; PostgreSQL stores hashes, metadata,
and lifecycle state.

The initial migration is
[`dashboard/database/migrations/001_initial.sql`](dashboard/database/migrations/001_initial.sql).
It enables row-level security on every tenant-owned table. Application
transactions must set `SET LOCAL app.tenant_id` after authenticating the
request. Missing tenant context intentionally returns no rows.

## SaaS security rules

1. Authenticate with OIDC/SAML-capable identity, then resolve a membership and
   role before opening a tenant transaction.
2. Use a least-privilege API database role; migration ownership is separate.
3. Never place provider API keys in tenant rows unencrypted. Store references to
   a secrets manager and redact credentials from logs and telemetry.
4. Enforce quotas and rate limits before dispatching model or media work.
5. Use an idempotency key for every mutating API request and a durable job ID
   for every worker task.
6. Keep self-hosted manager execution separate from hosted tenant workloads;
   project lifecycle remains unavailable through the root broker.

## Delivery phases

1. Foundation: migration, database health, tenant context middleware, and
   repository interfaces.
2. Persistence: projects, conversations, registry items, and audit events move
   behind repositories with transaction-scoped tenant IDs.
3. Workers: queue-backed crawl, embedding, media, and translation workers with
   retry/dead-letter handling.
4. SaaS: identity, organizations, quotas, billing metering, object storage,
   regional policy, export, and deletion workflows.
5. Enterprise isolation: dedicated database/cluster options and customer keys.

The current release implements the foundation only; it does not claim that
authentication, billing, or asynchronous workers are complete.
