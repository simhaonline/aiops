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

grep -Fq 'operation is not allowlisted' dashboard/broker/main.go
grep -Fq 'project symlink escapes /srv/projects' dashboard/broker/main.go
grep -Fq 'context.WithTimeout' dashboard/broker/main.go
! grep -Eq '(bash -c|sh -c|/bin/bash|/bin/sh)' dashboard/broker/main.go

grep -Fq 'network_mode: host' scripts/aiops-dashboard-manager
grep -Fq 'cap_drop: [ALL]' scripts/aiops-dashboard-manager
grep -Fq 'AIOPS_BROKER_SOCKET' scripts/aiops-dashboard-manager
! grep -Fq '/var/run/docker.sock:' scripts/aiops-dashboard-manager

scripts/aiops-dashboard-manager help >/dev/null

echo 'AIOPS-DASHBOARD ARCHITECTURE/SECURITY/TELEMETRY REGRESSION: PASS'
