# SIMHA AiOps Dashboard

The dashboard includes the native SIMHA Studio product shell for text,
codebases, PDFs and documents, images, video, voice, translation, knowledge,
workflows, projects, operations, and a governed skills/agents/MCP/plugins
registry. The current release provides the UI and capability contract; full
streaming conversations, persistence, media workers, and workflow execution
are subsequent backend layers. See [PRODUCT.md](PRODUCT.md) and the repository
root [ARCHITECTURE-REPORT.md](../ARCHITECTURE-REPORT.md) for the capability map,
request lifecycle, and trust boundaries.

A security-first operations interface composed of four deliberately separate
processes:

- Next.js web UI on `127.0.0.1:4600`
- NestJS API on `127.0.0.1:4601`
- Go allowlisted operation broker on a protected Unix socket
- Python telemetry collector on `127.0.0.1:9108`

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

These views are currently mock-backed. Authentication, live usage aggregation,
payment providers, API-key storage, and billing actions must be connected to
the authenticated SaaS API before production use.

## Development

```bash
npm install
npm run build
(cd broker && go test ./...)
python3 -m unittest discover telemetry/tests
```

Use `aiops-dashboard-manager` for production installation, lifecycle, Nginx/TLS,
verification, backup and restore.
