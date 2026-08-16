#!/usr/bin/env bash
readonly AIOPS_SCRIPT_VERSION="1.0.0"
set -Eeuo pipefail
IFS=$'\n\t'

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${1:-$ROOT/scripts/wireguard-manager}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

bash -n "$SCRIPT"
"$SCRIPT" help >/dev/null
"$SCRIPT" version | grep -Fq 'wireguard-manager 1.0.0'

grep -Fq 'CLIENT_DIR="${WG_DIR}/client"' "$SCRIPT"
grep -Fq 'LEGACY_CLIENT_DIR="/root/wireguard-clients"' "$SCRIPT"
grep -Fq 'migrate_legacy_client_storage' "$SCRIPT"
grep -Fq 'CLIENT_CONFIG="${CLIENT_DIR}/${client_name}.conf"' "$SCRIPT"
grep -Fq 'CLIENT_QR="${CLIENT_DIR}/${client_name}-qr.png"' "$SCRIPT"
grep -Fq 'install -d -m 700 "$CLIENT_DIR"' "$SCRIPT"

if grep -Eq '^CLIENT_DIR="/root/wireguard-clients"$' "$SCRIPT"; then
    echo 'legacy root client directory is still configured as active' >&2
    exit 1
fi

(
    set -- help
    # shellcheck disable=SC1090
    source "$SCRIPT" >/dev/null
    WG_DIR="$TMP/etc/wireguard"
    WG_ENV="$WG_DIR/wg0.env"
    CLIENT_DIR="$WG_DIR/client"
    LEGACY_CLIENT_DIR="$TMP/root/wireguard-clients"
    install -d -m 700 "$WG_DIR" "$LEGACY_CLIENT_DIR"
    printf 'CLIENT_DIR=%q\n' "$LEGACY_CLIENT_DIR" > "$WG_ENV"
    printf 'private-client-material\n' > "$LEGACY_CLIENT_DIR/mobile.conf"
    chmod 600 "$WG_ENV" "$LEGACY_CLIENT_DIR/mobile.conf"

    migrate_legacy_client_storage

    [[ -f "$CLIENT_DIR/mobile.conf" ]]
    [[ ! -e "$LEGACY_CLIENT_DIR/mobile.conf" ]]
    [[ "$(stat -c '%a' "$CLIENT_DIR")" == 700 ]]
    [[ "$(stat -c '%a' "$CLIENT_DIR/mobile.conf")" == 600 ]]
    grep -Fq "CLIENT_DIR=$CLIENT_DIR" "$WG_ENV"
)

echo 'WIREGUARD CLIENT STORAGE REGRESSION: PASS'
