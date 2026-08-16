#!/usr/bin/env bash
readonly AIOPS_SCRIPT_VERSION="1.0.1"
set -Eeuo pipefail
IFS=$'\n\t'

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
FORGEJO="$ROOT/scripts/forgejo-manager"
RUNNER="$ROOT/scripts/forgejo-runner-manager"

bash -n "$FORGEJO" "$RUNNER"
bash "$FORGEJO" help | grep -Fq 'Rootless Forgejo + PostgreSQL'
bash "$RUNNER" help | grep -Fq 'Dedicated rootless Podman'

grep -Fq 'codeberg.org/forgejo/forgejo:16.0.1-rootless' "$FORGEJO"
grep -Fq 'FORGEJO_HTTP_BIND=127.0.0.1' "$FORGEJO"
grep -Fq 'internal: true' "$FORGEJO"
grep -Fq 'DISABLE_REGISTRATION: "true"' "$FORGEJO"
grep -Fq 'rootless' "$FORGEJO"

grep -Fq 'privileged: false' "$RUNNER"
grep -Fq 'podman/podman.sock' "$RUNNER"
grep -Fq '@sha256:' "$RUNNER"
grep -Fq 'capacity: 1' "$RUNNER"
! grep -Fq '/var/run/docker.sock' "$RUNNER"

echo 'FORGEJO/RUNNER TRUST-ZONE REGRESSION: PASS'
