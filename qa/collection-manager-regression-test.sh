#!/usr/bin/env bash
readonly AIOPS_SCRIPT_VERSION="1.0.0"
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_MANAGER="$ROOT/scripts/project-manager"
COLLECTION_MANAGER="$ROOT/scripts/collection-manager"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT

mkdir -p "$TMP/bin"
cat >"$TMP/bin/docker" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ " $* " == *" run "* ]]; then
  volume=""; output=""
  while (($#)); do
    case "$1" in --volume) volume="$2"; shift 2 ;; /data/*.md) output="${1#/data/}"; shift ;; *) shift ;; esac
  done
  host="${volume%%:/data:rw}"
  printf '# collected fixture\n' >"$host/$output"
fi
exit 0
EOF
cat >"$TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$TMP/bin/nginx-manager" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$AIOPS_TEST_NGINX_LOG"
EOF
chmod 0755 "$TMP/bin/"*

PATH="$TMP/bin:$PATH" bash "$PROJECT_MANAGER" init "$TMP/project" collection-test >/dev/null
PATH="$TMP/bin:$PATH" bash "$COLLECTION_MANAGER" init "$TMP/project" docs https://example.com/docs >/dev/null
grep -Fq 'ALLOWED_HOST=example.com' "$TMP/project/.aiops/collections/config/docs.env"
grep -Eq 'SCRAPLING_IMAGE=ghcr.io/d4vinci/scrapling@sha256:[0-9a-f]{64}$' "$TMP/project/.aiops/collections/config/docs.env"
PATH="$TMP/bin:$PATH" bash "$COLLECTION_MANAGER" crawl "$TMP/project" docs >/dev/null
find "$TMP/project/.aiops/collections/data/docs" -type f -name '*.md' -print -quit | grep -q .
PATH="$TMP/bin:$PATH" bash "$COLLECTION_MANAGER" verify "$TMP/project" >/dev/null
PATH="$TMP/bin:$PATH" bash "$COLLECTION_MANAGER" ui-enable "$TMP/project" >/dev/null
grep -Fq '127.0.0.1:${AIOPS_COLLECTION_PORT}:8080' "$TMP/project/.aiops/features/collection-ui.yaml"
AIOPS_TEST_NGINX_LOG="$TMP/nginx.log" AIOPS_NGINX_MANAGER="$TMP/bin/nginx-manager" PATH="$TMP/bin:$PATH" \
  bash "$COLLECTION_MANAGER" edge-add "$TMP/project" collections.example.test admin@example.test >/dev/null
grep -Fq 'proxy-add collections.example.test http://127.0.0.1:19080 collectionadmin' "$TMP/nginx.log"
AIOPS_TEST_NGINX_LOG="$TMP/nginx.log" AIOPS_NGINX_MANAGER="$TMP/bin/nginx-manager" PATH="$TMP/bin:$PATH" \
  bash "$COLLECTION_MANAGER" edge-remove "$TMP/project" >/dev/null
PATH="$TMP/bin:$PATH" bash "$COLLECTION_MANAGER" backup "$TMP/project" "$TMP/collections.tar.gz" >/dev/null
PATH="$TMP/bin:$PATH" bash "$PROJECT_MANAGER" init "$TMP/restored" restored-test >/dev/null
PATH="$TMP/bin:$PATH" bash "$COLLECTION_MANAGER" restore "$TMP/collections.tar.gz" "$TMP/restored" >/dev/null
PATH="$TMP/bin:$PATH" bash "$COLLECTION_MANAGER" verify "$TMP/restored" >/dev/null

if PATH="$TMP/bin:$PATH" bash "$COLLECTION_MANAGER" init "$TMP/project" bad http://127.0.0.1/private >/dev/null 2>&1; then
  echo 'unsafe collection URL was accepted' >&2; exit 1
fi

echo 'COLLECTION-MANAGER POLICY/CRAWL/UI/BACKUP/RESTORE REGRESSION: PASS'
