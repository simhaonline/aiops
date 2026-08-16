#!/usr/bin/env bash
readonly AIOPS_SCRIPT_VERSION="1.0.1"
set -Eeuo pipefail
IFS=$'\n\t'

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

for file in "$ROOT/scripts/system-manager"; do
  if grep -Eq 'sshd[[:space:]]+-T.*\|.*awk .*exit' "$file"; then
    printf '[FAIL] unsafe sshd early-exit pipeline remains: %s\n' "$file" >&2
    exit 1
  fi
  if grep -Eq 'ufw status.*\|.*head' "$file"; then
    printf '[FAIL] unsafe ufw/head pipeline remains: %s\n' "$file" >&2
    exit 1
  fi
done

echo 'PIPEFAIL/SIGPIPE SAFETY REGRESSION: PASS'
