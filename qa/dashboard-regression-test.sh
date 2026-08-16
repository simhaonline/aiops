#!/usr/bin/env bash
readonly AIOPS_SCRIPT_VERSION="1.0.0"
set -Eeuo pipefail
IFS=$'\n\t'

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 -m json.tool dashboard/package.json >/dev/null
python3 -m json.tool dashboard/apps/web/package.json >/dev/null
python3 -m json.tool dashboard/apps/api/package.json >/dev/null
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover dashboard/telemetry/tests >/dev/null

grep -Fq ':root[data-theme="dark"]' dashboard/apps/web/app/styles.css
grep -Fq '@media(max-width:760px)' dashboard/apps/web/app/styles.css
grep -Fq 'aria-label="Search"' dashboard/apps/web/app/ui/dashboard-shell.tsx
grep -Fq 'localStorage.setItem("aiops-theme"' dashboard/apps/web/app/ui/theme-toggle.tsx
for modality in text code document image video voice translation; do
  grep -Fq "id:\"$modality\"" dashboard/apps/api/src/workspace.controller.ts
done
grep -Fq 'autoInstall:false' dashboard/apps/api/src/workspace.controller.ts
grep -Fq 'quarantine-first' dashboard/apps/api/src/workspace.controller.ts
for surface in Studio Codebases Knowledge Media Workflows Registry Projects Operations; do
  grep -Fq "$surface" dashboard/apps/web/app/ui/dashboard-shell.tsx
done
grep -Fq 'camera=(self), microphone=(self)' dashboard/apps/web/next.config.ts
grep -Fq '"pg"' dashboard/apps/api/package.json
grep -Fq 'AIOPS_DATABASE_URL' scripts/aiops-dashboard-manager
grep -Fq 'ENABLE ROW LEVEL SECURITY' dashboard/database/migrations/001_initial.sql
grep -Fq 'create_hypertable' dashboard/database/migrations/001_initial.sql
grep -Fq 'vector(1536)' dashboard/database/migrations/001_initial.sql
grep -Fq 'app.tenant_id' dashboard/database/migrations/001_initial.sql

grep -Fq 'operation is not allowlisted' dashboard/broker/main.go
grep -Fq 'project symlink escapes /srv/projects' dashboard/broker/main.go
grep -Fq 'context.WithTimeout' dashboard/broker/main.go
grep -Fq 'case "project.start", "project.stop":' dashboard/broker/main.go
! grep -Fq '"project.start"' dashboard/apps/api/src/operations.controller.ts
! grep -Fq '"project.stop"' dashboard/apps/api/src/operations.controller.ts
! grep -Eq '(bash -c|sh -c|/bin/bash|/bin/sh)' dashboard/broker/main.go

grep -Fq 'network_mode: host' scripts/aiops-dashboard-manager
grep -Fq 'HOSTNAME: 127.0.0.1' scripts/aiops-dashboard-manager
! grep -Fq 'HOSTNAME: 0.0.0.0' scripts/aiops-dashboard-manager
grep -Fq 'cap_drop: [ALL]' scripts/aiops-dashboard-manager
grep -Fq 'AIOPS_BROKER_SOCKET' scripts/aiops-dashboard-manager
! grep -Fq '/var/run/docker.sock:' scripts/aiops-dashboard-manager

scripts/aiops-dashboard-manager help >/dev/null

echo 'AIOPS-DASHBOARD ARCHITECTURE/SECURITY/TELEMETRY REGRESSION: PASS'
