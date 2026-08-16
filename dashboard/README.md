# SIMHA AiOps Dashboard

A security-first operations interface composed of four deliberately separate
processes:

- Next.js web UI on `127.0.0.1:4600`
- NestJS API on `127.0.0.1:4601`
- Go allowlisted operation broker on a protected Unix socket
- Python telemetry collector on `127.0.0.1:9108`

The web and API processes are unprivileged. Only the broker may invoke manager
commands, and it accepts seven fixed operations with strict project/name
validation. It does not implement arbitrary commands or an interactive shell.

## Development

```bash
npm install
npm run build
(cd broker && go test ./...)
python3 -m unittest discover telemetry/tests
```

Use `aiops-dashboard-manager` for production installation, lifecycle, Nginx/TLS,
verification, backup and restore.
