# Q-AI repository audit

**Audit date:** 2026-08-16  
**Repository:** `simhaonline/aiops`  
**Baseline:** `main` at `1533f13`  
**Extension branch:** temporary review branch, merged and removed after release

## Executive summary

SIMHA AiOps is an Ubuntu 24.04 operations-manager suite with an optional
Next.js/NestJS/Go/Python dashboard. It is not currently a general-purpose AI
application server. The existing AI boundary is a managed LiteLLM process and
provider-specific shell managers; the dashboard exposes capability metadata and
restricted infrastructure operations, but does not execute model inference.

Q-AI must therefore be an additive, feature-flagged orchestration service in
the existing NestJS API boundary. It must call the existing LiteLLM loopback
gateway rather than duplicate provider SDKs or bypass provider credentials.
The first implementation can provide deterministic orchestration algorithms,
normalized evidence, audit metadata, and an optional evaluation endpoint while
leaving the current Studio and operations behavior unchanged.

## Architecture map

```text
SIMHA AiOps
├── CLI / managers
│   ├── scripts/aiops                 unified dispatcher and scheduled refresh
│   ├── scripts/litellm-manager       LiteLLM lifecycle, keys, model catalog
│   ├── scripts/ollama-manager        Ollama Cloud policy/catalog
│   ├── scripts/project-manager       isolated project runtime and AI assets
│   └── scripts/collection-manager    restricted Scrapling collection worker
├── Dashboard
│   ├── apps/web                      Next.js Studio and platform portal UI
│   ├── apps/api                      NestJS health, overview, operations, workspace
│   ├── broker                        Go allowlisted root operation broker
│   └── telemetry                     loopback Python host snapshot service
├── AI/provider boundary
│   └── LiteLLM                       external loopback gateway on 127.0.0.1:4000
├── Persistence
│   ├── filesystem/systemd/Docker     existing manager and project state
│   └── PostgreSQL + pgvector +       optional SaaS foundation; migration exists,
│       TimescaleDB                    complete repositories do not yet exist
├── Cache/queues                       none discovered in the application
├── Authentication                      Nginx edge / dashboard token; no in-app
│                                      OIDC, JWT, tenant middleware, or RBAC yet
├── Observability                       JSON broker audit, Python telemetry,
│                                      systemd logs; no OpenTelemetry/Prometheus
│                                      Q-AI metrics pipeline yet
└── Tests/CI                            shell regression suite, NestJS tests,
                                       Go tests, Python unittest, release validator
```

## Existing AI/provider wiring

| Capability | Current implementation | Q-AI integration point |
|---|---|---|
| Provider lifecycle | `scripts/litellm-manager` | Preserve; Q-AI uses its loopback endpoint/configuration |
| NVIDIA NIM discovery | `litellm-manager` verified-free catalog and API | Read model inventory through LiteLLM/provider metadata, never keys in Q-AI |
| OpenRouter discovery | `litellm-manager` strict `:free` parser | Same as above |
| Ollama Cloud | `scripts/ollama-manager` Cloud-only catalog and scheduled sync | Treat as an eligible LiteLLM/Ollama route |
| Model routing | LiteLLM configuration and explicit verified-free policy | Q-AI adds request-level adaptive selection above LiteLLM |
| Prompt management | No centralized prompt service discovered | Q-AI accepts normalized request context only |
| Streaming/tool calls/MCP | Capability metadata and project-local configuration; no API execution engine | Future adapter fields remain optional |
| Cost/usage | Provider configuration and planned Timescale schema; no live usage repository | Q-AI emits usage metadata and audit events |

## API and frontend boundaries

`dashboard/apps/api/src/main.ts` creates a Fastify-backed NestJS application on
loopback port 4601, applies a strict global `ValidationPipe`, and prefixes
routes with `/api`. Existing controllers are:

- `HealthController`: service and optional PostgreSQL health.
- `OverviewController`: telemetry snapshot and project inventory.
- `OperationsController`: token-authorized, five-action broker allowlist.
- `WorkspaceController`: modality, registry, routing-policy, and safety metadata.

`dashboard/apps/web` contains the existing Studio shell and the new platform
management route shell. The frontend has no provider secrets, no model-call
client, and no Q-AI state store. The correct UI integration is a future admin
surface backed by Q-AI read-only metrics; it must not make provider calls from
the browser.

## Persistence, tenancy, and deployment

`dashboard/apps/api/src/database.service.ts` provides an optional bounded
`pg` pool configured by `AIOPS_DATABASE_URL`. The migration
`dashboard/database/migrations/001_initial.sql` creates tenant-owned `app`
tables, pgvector knowledge chunks, TimescaleDB request events, and RLS policies.
However, the API currently has no authenticated tenant context or transaction
helper that sets `SET LOCAL app.tenant_id`. Q-AI persistence must not pretend
that RLS is active until that context boundary exists.

The dashboard is deployed by `scripts/aiops-dashboard-manager` as unprivileged
API/web containers, a root Go broker, and a telemetry service. The broker must
remain outside Q-AI model execution. Q-AI calls belong in the unprivileged API
or a future worker service and must never receive Docker or root credentials.

## Security and reliability findings relevant to Q-AI

1. Provider credentials are root-only in `/etc/litellm/litellm.env`; Q-AI must
   call LiteLLM and must never copy keys into API responses, logs, or database
   evidence.
2. There is no existing request rate-limit, queue, circuit-breaker, or retry
   abstraction in the NestJS application. Q-AI needs bounded concurrency and
   timeouts in its own service boundary without changing operations behavior.
3. API authentication is a dashboard token for operations, not a tenant-aware
   user identity. Q-AI endpoints must be disabled by default until a suitable
   auth/tenant policy is available; an internal evaluation mode must be
   explicitly marked non-production.
4. Model responses are untrusted input. Q-AI must validate structured output,
   avoid hidden chain-of-thought storage, and prevent one model's text from
   becoming another model's system instruction.
5. Existing provider model discovery is shell-managed and can change upstream.
   Q-AI model metadata must tolerate missing capability/cost fields and fail
   closed for unavailable or policy-ineligible models.

## Conflicts and deviations from the specification

- No existing provider adapter interface was found in TypeScript, Python, or
  Go. Creating a small internal adapter contract around the LiteLLM HTTP API is
  an architectural gap, not a duplicate provider implementation.
- No queue/cache/telemetry SDK exists in the application. The initial Q-AI
  foundation will use bounded in-process concurrency and structured metadata;
  durable workers and metrics export remain later phases.
- No financial/trading domain was found. Q-AI will remain domain-neutral and
  will not add BUY/SELL semantics.
- No calibration dataset or resolved-outcome table exists. Calibration and
  learning APIs must be optional and report insufficient data rather than claim
  accuracy.
- The repository has historically committed directly to `main`; this extension
  was reviewed on a temporary feature branch and merged back to `main`.

## Recommended extension location

Add a bounded `dashboard/apps/api/src/q-ai/` module containing:

```text
q-ai/
├── q-ai.module.ts             feature flag and dependency wiring
├── q-ai.config.ts             validated environment/config defaults
├── q-ai.types.ts              request, evidence, state, decision contracts
├── provider-client.ts         LiteLLM-compatible provider-neutral client
├── registry.service.ts        eligible model/provider metadata
├── routing.service.ts         configurable score and exploration policy
├── executor.service.ts        parallel calls, timeout, partial failures
├── fusion.service.ts          correlation, interference, Bayesian fusion
├── measurement.service.ts     calibrated confidence and stability
├── orchestrator.service.ts    bounded pipeline and early termination
└── q-ai.controller.ts         disabled-by-default API boundary
```

This keeps the existing controllers and Studio behavior stable. A later
repository layer can persist Q-AI requests and Timescale usage once tenant
authentication and transaction context are implemented.

## Discovery commands and validation

The audit inspected Git state/history, manifests, dashboard source, manager
scripts, database migration, deployment configuration, documentation, and the
existing QA suite. The baseline release validator is `bash
qa/validate-release.sh`; dashboard-specific checks are in
`qa/dashboard-regression-test.sh`. No Q-AI code was present before this audit.
