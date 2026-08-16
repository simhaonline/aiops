#!/usr/bin/env bash
readonly AIOPS_SCRIPT_VERSION="1.0.0"
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/project-manager"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT

mkdir -p "$TMP/bin"
cat >"$TMP/bin/docker" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ " $* " == *" compose "* ]]
exit 0
EOF
chmod 0755 "$TMP/bin/docker"
cat >"$TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod 0755 "$TMP/bin/curl"
cat >"$TMP/bin/nginx-manager" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$AIOPS_TEST_NGINX_LOG"
EOF
chmod 0755 "$TMP/bin/nginx-manager"

PATH="$TMP/bin:$PATH" bash "$SCRIPT" init "$TMP/source" isolated-test >/dev/null

test -f "$TMP/source/AGENTS.md"
test -f "$TMP/source/.aiops/compose.yaml"
test -d "$TMP/source/.aiops/home/.codex/skills"
test -d "$TMP/source/.aiops/home/.codex/plugins"
grep -Fq 'CODEX_HOME: /home/developer/.codex' "$TMP/source/.aiops/compose.yaml"
grep -Fq 'source: ./.aiops/home' "$TMP/source/.aiops/compose.yaml"
! grep -Fq '/var/run/docker.sock' "$TMP/source/.aiops/compose.yaml"
! grep -Eq '^AIOPS_UID=0$|^AIOPS_GID=0$' "$TMP/source/.aiops/project.env"
grep -Eq '^AIOPS_CODE_SERVER_PORT=18[0-9]{3}$' "$TMP/source/.aiops/project.env"

printf 'project-only-skill\n' >"$TMP/source/.aiops/home/.codex/skills/identity.txt"
printf 'project source\n' >"$TMP/source/example.txt"
PATH="$TMP/bin:$PATH" bash "$SCRIPT" verify "$TMP/source" >/dev/null
PATH="$TMP/bin:$PATH" bash "$SCRIPT" feature-enable "$TMP/source" code-server >/dev/null
PATH="$TMP/bin:$PATH" bash "$SCRIPT" feature-enable "$TMP/source" goose >/dev/null
PATH="$TMP/bin:$PATH" bash "$SCRIPT" feature-enable "$TMP/source" opencodex >/dev/null
PATH="$TMP/bin:$PATH" bash "$SCRIPT" feature-enable "$TMP/source" mulerouter >/dev/null
test -f "$TMP/source/.aiops/features/code-server.yaml"
test "$(stat -c %a "$TMP/source/.aiops/secrets/code-server.env")" = 600
! grep -Fq 'AIOPS_CODE_SERVER_PASSWORD=' "$TMP/source/.aiops/project.env"
AIOPS_TEST_NGINX_LOG="$TMP/nginx.log" AIOPS_NGINX_MANAGER="$TMP/bin/nginx-manager" PATH="$TMP/bin:$PATH" \
  bash "$SCRIPT" edge-add "$TMP/source" code-server ide.example.test admin@example.test projectadmin >/dev/null
grep -Fq 'proxy-add ide.example.test http://127.0.0.1:' "$TMP/nginx.log"
grep -Fq 'ssl-issue ide.example.test admin@example.test' "$TMP/nginx.log"
test -f "$TMP/source/.aiops/features/code-server.edge"
AIOPS_TEST_NGINX_LOG="$TMP/nginx.log" AIOPS_NGINX_MANAGER="$TMP/bin/nginx-manager" PATH="$TMP/bin:$PATH" \
  bash "$SCRIPT" edge-remove "$TMP/source" code-server >/dev/null
grep -Fq 'proxy-remove ide.example.test' "$TMP/nginx.log"
test ! -e "$TMP/source/.aiops/features/code-server.edge"
AIOPS_SECRET_VALUE='mr_test-project-key' PATH="$TMP/bin:$PATH" \
  bash "$SCRIPT" secret-set "$TMP/source" mulerouter >/dev/null
grep -Fq 'MULEROUTER_API_KEY=mr_test-project-key' "$TMP/source/.aiops/secrets/runtime.env"
test "$(stat -c %a "$TMP/source/.aiops/secrets/runtime.env")" = 600
PATH="$TMP/bin:$PATH" bash "$SCRIPT" backup "$TMP/source" "$TMP/project.tar.gz" >/dev/null

test -s "$TMP/project.tar.gz"
test -s "$TMP/project.tar.gz.sha256"
bash "$SCRIPT" restore "$TMP/project.tar.gz" "$TMP/restored" >/dev/null
cmp "$TMP/source/example.txt" "$TMP/restored/example.txt"
cmp "$TMP/source/.aiops/home/.codex/skills/identity.txt" \
  "$TMP/restored/.aiops/home/.codex/skills/identity.txt"
cmp "$TMP/source/.aiops/secrets/runtime.env" "$TMP/restored/.aiops/secrets/runtime.env"

echo 'PROJECT-MANAGER ISOLATION/BACKUP/RESTORE REGRESSION: PASS'
