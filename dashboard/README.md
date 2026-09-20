# SIMHA AiOps Dashboard

The dashboard includes the native SIMHA Studio product shell for text,
codebases, PDFs and documents, images, video, voice, translation, knowledge,
workflows, projects, operations, and a governed skills/agents/MCP/plugins
registry. The API now provides tenant-scoped persistence and a PostgreSQL-backed
worker lifecycle for repository, knowledge, media, and workflow jobs. Provider
credentials remain explicit configuration. See [PRODUCT.md](PRODUCT.md) and the repository
root [ARCHITECTURE-REPORT.md](../ARCHITECTURE-REPORT.md) for the capability map,
request lifecycle, and trust boundaries.

A security-first operations interface composed of four deliberately separate
processes:

- Next.js web UI on `127.0.0.1:11080`
- NestJS API on `127.0.0.1:11081`
- Go allowlisted operation broker on a protected Unix socket
- Python telemetry collector on `127.0.0.1:11082`

The web and API processes are unprivileged. Only the broker may invoke manager
commands, and it accepts five fixed operations with strict project/name
validation. Project start/stop is deliberately excluded because project Compose
files are user-editable and must never be executed by the root broker. It does
not implement arbitrary commands or an interactive shell.

For SaaS deployments, PostgreSQL is the system of record, pgvector stores
embeddings, and TimescaleDB stores usage and telemetry. The tenant-isolated
schema and migration guidance are in [`database/`](database/). Set
`AIOPS_DATABASE_URL` for persistence; local/read-only installations may leave
it unset.

## Platform portal

The route `/usage` provides the first platform-management slice: organization
switching, navigation, balance and cost summaries, GMT+4 usage filters, export
feedback, service breakdowns, request-history empty states, and light/dark
mode. The same shell resolves `/home`, `/api-keys`, `/playground`, `/models`,
`/logs`, `/batches`, `/storage`, `/webhooks`, `/billing`, `/top-up`,
`/invoices`, `/users`, `/teams`, `/projects`, `/audit-logs`, `/security`,
`/settings`, and `/docs` to safe management views.

These platform views remain separate from the workspace shell. Usage and billing
providers are still integration work; workspace CRUD and operations job status
are backed by the authenticated API.

## Q-AI orchestration

The optional Q-AI module is documented in [`../docs/q-ai/`](../docs/q-ai/).
It is disabled by default, calls the existing LiteLLM loopback gateway, and
uses classical quantum-inspired probability/interference terminology without
claiming physical quantum computing. Enable it only after configuring an
authenticated internal deployment and a reviewed `Q_AI_MODELS_JSON` registry.
Production activation additionally requires `Q_AI_PRODUCTION_ACK=true`; both
flags are intentionally false in the generated compose environment.

## Development

```bash
npm install
npm run dev:deps
npm run db:migrate
npm run build
(cd apps/api && npm run worker)
(cd broker && go test ./...)
python3 -m unittest discover telemetry/tests
```

`dev:deps` starts the PostgreSQL/MinIO services in `docker-compose.dev.yml`.
Copy `.env.example` to a server-side environment file, configure
`AIOPS_TENANT_ID`, and apply migrations before creating workspace records.
Set `AIOPS_EMBEDDINGS_DEV=true` or `AIOPS_MEDIA_DEV=true` only for explicit
local adapter tests; production requires real provider credentials.

Use `aiops-dashboard-manager` for production installation, lifecycle, Nginx/TLS,
verification, backup and restore.
