#!/usr/bin/env bash
# LEGACY SUPPORT SNAPSHOT
# Suite archive: pre-1.0.1 internal manager lineage
# This file is NOT installed on PATH and is preserved for rollback/reference only.
readonly AIOPS_LEGACY_RELEASE="1.0.1"
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

# =============================================================================
# nginx-manager
# Version: 1.3.0
# Target: Ubuntu 24.04 LTS
#
# Production Nginx + Certbot reverse-proxy manager.
#
# Primary deployment:
#
#   Internet
#      |
#      | HTTPS :443 + Basic Auth
#      v
#   152.53.67.111
#   Nginx
#      |
#      v
#   127.0.0.1:3080
#   DeepSeek Harness
#      |
#      v
#   127.0.0.1:11434/v1
#   Ollama
#
# Design:
#   - One direct Nginx edge on the application server.
#   - No Plesk dependency.
#   - No public Harness port.
#   - No public Ollama port.
#   - Reverse proxies are authenticated by default.
#   - Certbot uses webroot; it does NOT rewrite managed Nginx configs.
#   - Certificates renew through Certbot with a safe Nginx deploy hook.
#   - Every managed config mutation is validated with nginx -t before reload.
#   - Managed sites are reproducible from /etc/nginx-manager/sites/*.env.
# =============================================================================

readonly NGM_VERSION="1.3.0"
readonly NGM_MANAGER_PATH="/usr/local/bin/nginx-manager"
readonly NGM_LOCK_FILE="/run/lock/nginx-manager.lock"

readonly NGM_CONFIG="/etc/nginx-manager"
readonly NGM_SITES_DIR="${NGM_CONFIG}/sites"
readonly NGM_AUTH_DIR="${NGM_CONFIG}/auth"
readonly NGM_BACKUP_DIR="${NGM_CONFIG}/backups"
readonly NGM_DISABLED_DIR="${NGM_CONFIG}/disabled"
readonly NGM_GLOBAL_ENV="${NGM_CONFIG}/manager.env"

readonly NGM_ACME_ROOT="/var/lib/nginx-manager/acme"
readonly NGM_ACME_WELLKNOWN="${NGM_ACME_ROOT}/.well-known/acme-challenge"

readonly NGM_NGINX_GLOBAL="/etc/nginx/conf.d/00-nginx-manager-global.conf"
readonly NGM_SITES_AVAILABLE="/etc/nginx/sites-available"
readonly NGM_SITES_ENABLED="/etc/nginx/sites-enabled"

readonly NGM_RENEW_HOOK="/etc/letsencrypt/renewal-hooks/deploy/10-nginx-manager-reload"
readonly NGM_FALLBACK_RENEW_SERVICE="/etc/systemd/system/nginx-manager-certbot-renew.service"
readonly NGM_FALLBACK_RENEW_TIMER="/etc/systemd/system/nginx-manager-certbot-renew.timer"

readonly NGM_HARNESS_MANAGER="/usr/local/bin/harness-manager"
readonly NGM_HARNESS_UPSTREAM="http://127.0.0.1:3080"
readonly NGM_HARNESS_PORT="3080"

readonly NGM_HERMES_MANAGER="/usr/local/bin/hermes-manager"
readonly NGM_HERMES_UPSTREAM="http://127.0.0.1:9119"
readonly NGM_HERMES_PORT="9119"

readonly NGM_OLLAMA_PORT="11434"

readonly NGM_DEFAULT_SERVER_IP="${NGIN_SERVER_IP:-152.53.67.111}"
readonly NGM_DEFAULT_BODY_SIZE="${NGIN_CLIENT_MAX_BODY_SIZE:-170m}"

NGM_APT_LOCK_TIMEOUT="${APT_LOCK_TIMEOUT:-600}"
NGM_LOCK_TIMEOUT="${LOCK_TIMEOUT:-120}"
NGM_LOG_LINES="${LOG_LINES:-200}"

# -----------------------------------------------------------------------------
# Logging / errors
# -----------------------------------------------------------------------------

ngm_log()  { printf '\n==> %s\n' "$*"; }
ngm_info() { printf '[INFO] %s\n' "$*"; }
ngm_warn() { printf '[WARN] %s\n' "$*" >&2; }
ngm_die()  { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

ngm_err_trap() {
    local rc=$?
    local line="${BASH_LINENO[0]:-unknown}"
    printf '[ERROR] nginx-manager failed at line %s (exit %s).\n' "$line" "$rc" >&2
    exit "$rc"
}
trap ngm_err_trap ERR

ngm_require_root() {
    [[ ${EUID:-$(id -u)} -eq 0 ]] || ngm_die "Run this command with sudo/root."
}

ngm_require_cmd() {
    command -v "$1" >/dev/null 2>&1 || ngm_die "Required command missing: $1"
}

ngm_require_ubuntu_2404() {
    [[ -r /etc/os-release ]] || ngm_die "Cannot read /etc/os-release."
    # shellcheck disable=SC1091
    source /etc/os-release

    [[ "${ID:-}" == "ubuntu" ]] || ngm_die "Ubuntu is required."
    [[ "${VERSION_ID:-}" == "24.04" ]] || \
        ngm_die "This manager is validated for Ubuntu 24.04 LTS; found ${PRETTY_NAME:-unknown}."
}

ngm_lock() {
    ngm_require_root
    install -d -m 0755 /run/lock
    exec 9>"$NGM_LOCK_FILE"
    flock -w "$NGM_LOCK_TIMEOUT" 9 || ngm_die "Another nginx-manager operation is active."
}

ngm_apt() {
    DEBIAN_FRONTEND=noninteractive \
        apt-get -o "DPkg::Lock::Timeout=${NGM_APT_LOCK_TIMEOUT}" "$@"
}

# -----------------------------------------------------------------------------
# Self-install / manager identity
# -----------------------------------------------------------------------------

ngm_source_path() {
    readlink -f "${BASH_SOURCE[0]}"
}

ngm_canonical_version() {
    if [[ ! -r "$NGM_MANAGER_PATH" ]]; then
        printf 'not-installed\n'
        return 0
    fi

    local version=""
    version="$(
        sed -nE 's/^readonly NGM_VERSION="([^"]+)".*/\1/p' \
            "$NGM_MANAGER_PATH" | head -1
    )"
    printf '%s\n' "${version:-unknown}"
}

ngm_self_install() {
    local src
    src="$(ngm_source_path)"

    if [[ "$src" != "$NGM_MANAGER_PATH" ]]; then
        install -o root -g root -m 0755 "$src" "$NGM_MANAGER_PATH"
        ngm_info "Installed nginx-manager ${NGM_VERSION} -> ${NGM_MANAGER_PATH}"
    else
        chown root:root "$NGM_MANAGER_PATH"
        chmod 0755 "$NGM_MANAGER_PATH"
    fi
}

ngm_begin_mutation() {
    ngm_require_root
    ngm_require_ubuntu_2404
    ngm_lock
    ngm_self_install
}

# -----------------------------------------------------------------------------
# Validation helpers
# -----------------------------------------------------------------------------

ngm_validate_domain() {
    local domain="${1,,}"

    [[ ${#domain} -le 253 ]] || return 1
    [[ "$domain" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]] || return 1
    [[ "$domain" == *.* ]] || return 1
    [[ "$domain" != *..* ]] || return 1

    local label
    IFS='.' read -r -a _labels <<<"$domain"
    for label in "${_labels[@]}"; do
        [[ -n "$label" && ${#label} -le 63 ]] || return 1
        [[ "$label" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || return 1
    done
}

ngm_validate_username() {
    local user="$1"
    [[ "$user" =~ ^[A-Za-z0-9][A-Za-z0-9._@+-]{0,63}$ ]]
}

ngm_validate_email() {
    local email="$1"
    [[ "$email" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]
}

ngm_validate_upstream() {
    local upstream="$1"

    [[ "$upstream" != *[$'\n\r\t ;{}']* ]] || return 1

    if [[ "$upstream" =~ ^https?://127\.0\.0\.1:([0-9]{1,5})$ ]]; then
        local port="${BASH_REMATCH[1]}"
        (( port >= 1 && port <= 65535 ))
        return
    fi

    if [[ "$upstream" =~ ^https?://localhost:([0-9]{1,5})$ ]]; then
        local port="${BASH_REMATCH[1]}"
        (( port >= 1 && port <= 65535 ))
        return
    fi

    if [[ "$upstream" =~ ^https?://[A-Za-z0-9._-]+:([0-9]{1,5})$ ]]; then
        local port="${BASH_REMATCH[1]}"
        (( port >= 1 && port <= 65535 ))
        return
    fi

    return 1
}

ngm_validate_body_size() {
    local size="$1"
    [[ "$size" =~ ^[1-9][0-9]*[kKmMgG]$ ]]
}

ngm_site_env() {
    printf '%s/%s.env\n' "$NGM_SITES_DIR" "${1,,}"
}

ngm_site_conf() {
    printf '%s/nginx-manager-%s.conf\n' "$NGM_SITES_AVAILABLE" "${1,,}"
}

ngm_site_link() {
    printf '%s/nginx-manager-%s.conf\n' "$NGM_SITES_ENABLED" "${1,,}"
}

ngm_auth_file() {
    printf '%s/%s.htpasswd\n' "$NGM_AUTH_DIR" "${1,,}"
}

ngm_cert_fullchain() {
    printf '/etc/letsencrypt/live/%s/fullchain.pem\n' "${1,,}"
}

ngm_cert_privkey() {
    printf '/etc/letsencrypt/live/%s/privkey.pem\n' "${1,,}"
}

ngm_cert_exists() {
    [[ -s "$(ngm_cert_fullchain "$1")" && -s "$(ngm_cert_privkey "$1")" ]]
}

ngm_site_exists() {
    [[ -f "$(ngm_site_env "$1")" ]]
}

ngm_nginx_worker_user() {
    local user=""
    if [[ -r /etc/nginx/nginx.conf ]]; then
        user="$(
            awk '
                $1=="user" {
                    gsub(/;/,"",$2)
                    print $2
                    exit
                }
            ' /etc/nginx/nginx.conf
        )"
    fi
    printf '%s\n' "${user:-www-data}"
}

ngm_nginx_worker_group() {
    local user
    user="$(ngm_nginx_worker_user)"
    id -gn "$user" 2>/dev/null || printf '%s\n' "$user"
}

ngm_local_ipv4s() {
    ip -4 -o addr show scope global 2>/dev/null | \
        awk '{split($4,a,"/"); print a[1]}' | sort -u
}

ngm_domain_ipv4s() {
    getent ahostsv4 "$1" 2>/dev/null | awk '{print $1}' | sort -u
}

ngm_dns_check() {
    local domain="${1,,}"
    ngm_validate_domain "$domain" || ngm_die "Usage: nginx-manager dns-check DOMAIN"

    local resolved localips overlap=""

    resolved="$(ngm_domain_ipv4s "$domain" || true)"
    localips="$(ngm_local_ipv4s || true)"

    if [[ -z "$resolved" ]]; then
        ngm_warn "DNS A record for ${domain} did not resolve from this server."
        return 1
    fi

    overlap="$(
        comm -12 \
            <(printf '%s\n' "$resolved" | sed '/^$/d' | sort -u) \
            <(printf '%s\n' "$localips" | sed '/^$/d' | sort -u) || true
    )"

    echo "Domain:    $domain"
    echo "DNS IPv4:  $(tr '\n' ' ' <<<"$resolved" | xargs)"
    echo "Local IPv4: $(tr '\n' ' ' <<<"$localips" | xargs)"

    if [[ -n "$overlap" ]]; then
        echo "DNS status: MATCH"
        return 0
    fi

    ngm_warn "DNS does not directly resolve to a local IPv4 address."
    ngm_warn "If a CDN/proxy is intentionally in front, HTTP-01 may still work if port 80 reaches this origin."
    return 1
}

# -----------------------------------------------------------------------------
# OS packages / directories
# -----------------------------------------------------------------------------

ngm_install_dependencies() {
    local packages=(
        nginx
        certbot
        apache2-utils
        ca-certificates
        curl
        openssl
        iproute2
        util-linux
    )
    local missing=() pkg

    for pkg in "${packages[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | \
            grep -q '^install ok installed$'; then
            missing+=("$pkg")
        fi
    done

    if ((${#missing[@]} == 0)); then
        ngm_info "Required packages are already installed; skipping apt update."
        return 0
    fi

    ngm_log "Installing Nginx / Certbot dependencies"
    ngm_info "Missing: ${missing[*]}"
    ngm_apt update
    ngm_apt install -y --no-install-recommends "${missing[@]}"
}

ngm_ensure_dirs() {
    install -d -o root -g root -m 0755 \
        "$NGM_CONFIG" \
        "$NGM_SITES_DIR" \
        "$NGM_BACKUP_DIR" \
        "$NGM_DISABLED_DIR" \
        "$NGM_ACME_ROOT" \
        "$NGM_ACME_WELLKNOWN"

    local nginx_group
    nginx_group="$(ngm_nginx_worker_group)"

    install -d -o root -g "$nginx_group" -m 0750 "$NGM_AUTH_DIR"

    if [[ ! -f "$NGM_GLOBAL_ENV" ]]; then
        cat >"$NGM_GLOBAL_ENV" <<EOF
# nginx-manager global defaults
SERVER_IP=${NGM_DEFAULT_SERVER_IP}
DEFAULT_BODY_SIZE=${NGM_DEFAULT_BODY_SIZE}
EOF
    fi
    chown root:root "$NGM_GLOBAL_ENV"
    chmod 0644 "$NGM_GLOBAL_ENV"
}

ngm_write_global_nginx() {
    cat >"$NGM_NGINX_GLOBAL" <<'EOF'
# Managed by nginx-manager.
# Global settings used by nginx-manager reverse-proxy sites.

server_tokens off;

map $http_upgrade $nginx_manager_connection_upgrade {
    default upgrade;
    ''      close;
}
EOF

    chown root:root "$NGM_NGINX_GLOBAL"
    chmod 0644 "$NGM_NGINX_GLOBAL"
}

ngm_write_renew_hook() {
    install -d -o root -g root -m 0755 \
        /etc/letsencrypt/renewal-hooks/deploy

    cat >"$NGM_RENEW_HOOK" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
/usr/sbin/nginx -t
/bin/systemctl reload nginx
EOF
    chown root:root "$NGM_RENEW_HOOK"
    chmod 0755 "$NGM_RENEW_HOOK"
}

ngm_write_fallback_renew_timer() {
    cat >"$NGM_FALLBACK_RENEW_SERVICE" <<'EOF'
[Unit]
Description=Certbot renewal fallback for nginx-manager
After=network-online.target nginx.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/certbot renew --quiet
EOF

    cat >"$NGM_FALLBACK_RENEW_TIMER" <<'EOF'
[Unit]
Description=Run Certbot renewal twice daily for nginx-manager

[Timer]
OnCalendar=*-*-* 03,15:17:00
RandomizedDelaySec=1800
Persistent=true

[Install]
WantedBy=timers.target
EOF

    chown root:root "$NGM_FALLBACK_RENEW_SERVICE" "$NGM_FALLBACK_RENEW_TIMER"
    chmod 0644 "$NGM_FALLBACK_RENEW_SERVICE" "$NGM_FALLBACK_RENEW_TIMER"

    systemctl daemon-reload
    systemctl enable --now nginx-manager-certbot-renew.timer >/dev/null
}

ngm_ensure_renew_timer() {
    if systemctl cat certbot.timer >/dev/null 2>&1; then
        systemctl enable --now certbot.timer >/dev/null
        systemctl disable --now nginx-manager-certbot-renew.timer >/dev/null 2>&1 || true
        rm -f "$NGM_FALLBACK_RENEW_SERVICE" "$NGM_FALLBACK_RENEW_TIMER"
        systemctl daemon-reload
        ngm_info "Certbot renewal timer: certbot.timer"
    else
        ngm_write_fallback_renew_timer
        ngm_info "Certbot renewal timer: nginx-manager-certbot-renew.timer"
    fi
}

ngm_disable_default_site() {
    if [[ -L /etc/nginx/sites-enabled/default ]]; then
        rm -f /etc/nginx/sites-enabled/default
        ngm_info "Disabled Ubuntu default Nginx site."
    fi
}

ngm_prepare_common() {
    ngm_install_dependencies
    ngm_ensure_dirs
    ngm_write_global_nginx
    ngm_write_renew_hook
    ngm_disable_default_site

    systemctl unmask nginx.service >/dev/null 2>&1 || true
    systemctl enable --now nginx.service >/dev/null

    ngm_ensure_renew_timer
}

# -----------------------------------------------------------------------------
# Site metadata
# -----------------------------------------------------------------------------

ngm_write_site_env() {
    local domain="$1"
    local upstream="$2"
    local auth_required="$3"
    local body_size="$4"
    local auth_forward="${5:-strip}"

    [[ "$auth_forward" == "strip" || "$auth_forward" == "pass" ]] || ngm_die "Invalid Authorization forwarding mode."

    local file
    file="$(ngm_site_env "$domain")"

    cat >"$file" <<EOF
DOMAIN=${domain}
UPSTREAM=${upstream}
AUTH_REQUIRED=${auth_required}
BODY_SIZE=${body_size}
AUTH_FORWARD=${auth_forward}
EOF
    chown root:root "$file"
    chmod 0644 "$file"
}

ngm_load_site() {
    local domain="${1,,}"
    local file
    file="$(ngm_site_env "$domain")"

    [[ -f "$file" ]] || ngm_die "Managed site not found: $domain"

    DOMAIN=""
    UPSTREAM=""
    AUTH_REQUIRED=""
    BODY_SIZE=""
    AUTH_FORWARD="strip"

    # Values are written only after strict validation by nginx-manager.
    # shellcheck disable=SC1090
    source "$file"

    [[ "$DOMAIN" == "$domain" ]] || ngm_die "Site metadata domain mismatch: $file"
    ngm_validate_domain "$DOMAIN" || ngm_die "Invalid managed domain in $file"
    ngm_validate_upstream "$UPSTREAM" || ngm_die "Invalid upstream in $file"
    [[ "$AUTH_REQUIRED" == "yes" || "$AUTH_REQUIRED" == "no" ]] || \
        ngm_die "Invalid AUTH_REQUIRED in $file"
    ngm_validate_body_size "$BODY_SIZE" || ngm_die "Invalid BODY_SIZE in $file"
    [[ "$AUTH_FORWARD" == "strip" || "$AUTH_FORWARD" == "pass" ]] || \
        ngm_die "Invalid AUTH_FORWARD in $file"
}

ngm_list_domains() {
    find "$NGM_SITES_DIR" -maxdepth 1 -type f -name '*.env' -printf '%f\n' 2>/dev/null | \
        sed 's/\.env$//' | sort
}

# -----------------------------------------------------------------------------
# Authentication
# -----------------------------------------------------------------------------

ngm_secure_auth_file() {
    local domain="${1,,}"
    local file group
    file="$(ngm_auth_file "$domain")"
    group="$(ngm_nginx_worker_group)"

    [[ -f "$file" ]] || return 0

    chown root:"$group" "$file"
    chmod 0640 "$file"
}

ngm_auth_count() {
    local domain="${1,,}"
    local file
    file="$(ngm_auth_file "$domain")"

    [[ -f "$file" ]] || {
        printf '0\n'
        return 0
    }

    awk -F: 'NF >= 2 {count++} END {print count+0}' "$file"
}

ngm_auth_add_impl() {
    local domain="${1,,}"
    local user="$2"

    ngm_site_exists "$domain" || ngm_die "Managed site not found: $domain"
    ngm_validate_username "$user" || ngm_die "Invalid authentication username."

    local file
    file="$(ngm_auth_file "$domain")"

    ngm_log "Setting Nginx Basic Auth user '${user}' for ${domain}"

    if [[ -f "$file" ]]; then
        htpasswd -B "$file" "$user"
    else
        htpasswd -B -c "$file" "$user"
    fi

    ngm_secure_auth_file "$domain"
}

ngm_auth_add() {
    ngm_begin_mutation
    ngm_prepare_common

    local domain="${1:-}"
    local user="${2:-}"

    ngm_validate_domain "${domain,,}" || ngm_die "Usage: nginx-manager auth-add DOMAIN USER"
    [[ -n "$user" ]] || ngm_die "Usage: nginx-manager auth-add DOMAIN USER"

    ngm_auth_add_impl "${domain,,}" "$user"
    ngm_render_site "${domain,,}"
    ngm_apply_nginx
}

ngm_auth_delete() {
    ngm_begin_mutation
    ngm_prepare_common

    local domain="${1:-}"
    local user="${2:-}"

    ngm_validate_domain "${domain,,}" || ngm_die "Usage: nginx-manager auth-delete DOMAIN USER"
    ngm_validate_username "$user" || ngm_die "Invalid username."

    local file
    file="$(ngm_auth_file "${domain,,}")"
    [[ -f "$file" ]] || ngm_die "Authentication file does not exist."

    htpasswd -D "$file" "$user" >/dev/null || ngm_die "Authentication user not found: $user"
    ngm_secure_auth_file "${domain,,}"

    local count
    count="$(ngm_auth_count "${domain,,}")"
    if (( count == 0 )); then
        ngm_warn "No authentication users remain for ${domain}; authenticated requests will be rejected until a user is added."
    fi
}

ngm_auth_list() {
    local domain="${1:-}"
    ngm_validate_domain "${domain,,}" || ngm_die "Usage: nginx-manager auth-list DOMAIN"

    local file
    file="$(ngm_auth_file "${domain,,}")"

    echo "=== Authentication users: ${domain,,} ==="
    if [[ ! -f "$file" ]]; then
        echo "(none)"
        return 0
    fi

    cut -d: -f1 "$file" | sed '/^$/d'
}

# -----------------------------------------------------------------------------
# Nginx site rendering
# -----------------------------------------------------------------------------

ngm_render_http_pending() {
    local domain="$1"
    local conf="$2"

    cat >"$conf" <<EOF
# Managed by nginx-manager ${NGM_VERSION}
# TLS certificate pending.

server {
    listen 80;
    listen [::]:80;

    server_name ${domain};

    access_log /var/log/nginx/${domain}.access.log;
    error_log  /var/log/nginx/${domain}.error.log warn;

    location ^~ /.well-known/acme-challenge/ {
        root ${NGM_ACME_ROOT};
        default_type text/plain;
        auth_basic off;
        try_files \$uri =404;
    }

    location / {
        default_type text/plain;
        return 503 "TLS certificate setup pending for ${domain}\\n";
    }
}
EOF
}

ngm_auth_directives() {
    local domain="$1"
    local auth_required="$2"

    if [[ "$auth_required" == "yes" ]]; then
        cat <<EOF
        auth_basic "Protected Application";
        auth_basic_user_file $(ngm_auth_file "$domain");
EOF
    else
        cat <<'EOF'
        auth_basic off;
EOF
    fi
}

ngm_render_https() {
    local domain="$1"
    local upstream="$2"
    local auth_required="$3"
    local body_size="$4"
    local conf="$5"
    local auth_forward="${6:-strip}"

    local auth_block authorization_line
    auth_block="$(ngm_auth_directives "$domain" "$auth_required")"
    if [[ "$auth_forward" == "pass" ]]; then
        authorization_line='        proxy_set_header Authorization $http_authorization;'
    else
        authorization_line='        proxy_set_header Authorization "";'
    fi

    cat >"$conf" <<EOF
# Managed by nginx-manager ${NGM_VERSION}

server {
    listen 80;
    listen [::]:80;

    server_name ${domain};

    access_log /var/log/nginx/${domain}.access.log;
    error_log  /var/log/nginx/${domain}.error.log warn;

    location ^~ /.well-known/acme-challenge/ {
        root ${NGM_ACME_ROOT};
        default_type text/plain;
        auth_basic off;
        try_files \$uri =404;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name ${domain};

    ssl_certificate     $(ngm_cert_fullchain "$domain");
    ssl_certificate_key $(ngm_cert_privkey "$domain");

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_timeout 1d;
    ssl_session_cache shared:NGINXMANAGER_SSL:10m;
    ssl_session_tickets off;

    access_log /var/log/nginx/${domain}.ssl.access.log;
    error_log  /var/log/nginx/${domain}.ssl.error.log warn;

    client_max_body_size ${body_size};
    send_timeout 3600s;

    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location ^~ / {
${auth_block}

        proxy_pass ${upstream};
        proxy_http_version 1.1;

        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$http_host;
        proxy_set_header X-Forwarded-Port \$server_port;

        # Authorization policy is site-specific: strip edge credentials for
        # Basic-Auth sites, preserve application/API credentials for API sites.
${authorization_line}

        # WebSocket / streaming support.
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$nginx_manager_connection_upgrade;

        proxy_buffering off;
        proxy_request_buffering off;
        proxy_cache off;

        proxy_connect_timeout 30s;
        proxy_send_timeout 3600s;
        proxy_read_timeout 3600s;

        proxy_redirect off;
    }
}
EOF
}

ngm_render_site() {
    local domain="${1,,}"
    ngm_load_site "$domain"

    local conf temp
    conf="$(ngm_site_conf "$domain")"
    temp="$(mktemp /tmp/nginx-manager-site.XXXXXX)"

    if ngm_cert_exists "$domain"; then
        if [[ "$AUTH_REQUIRED" == "yes" && "$(ngm_auth_count "$domain")" -eq 0 ]]; then
            ngm_warn "Site ${domain} requires authentication but has no users."
        fi
        ngm_render_https "$DOMAIN" "$UPSTREAM" "$AUTH_REQUIRED" "$BODY_SIZE" "$temp" "$AUTH_FORWARD"
    else
        ngm_render_http_pending "$DOMAIN" "$temp"
    fi

    install -o root -g root -m 0644 "$temp" "$conf"
    rm -f "$temp"

    ln -sfn "$conf" "$(ngm_site_link "$domain")"
}

ngm_render_all_sites() {
    local domain
    while IFS= read -r domain; do
        [[ -n "$domain" ]] || continue
        ngm_render_site "$domain"
    done < <(ngm_list_domains)
}

ngm_apply_nginx() {
    nginx -t
    systemctl reload nginx
}

# -----------------------------------------------------------------------------
# Site lifecycle
# -----------------------------------------------------------------------------

ngm_proxy_add_impl() {
    local domain="${1,,}"
    local upstream="$2"
    local auth_user="${3:-}"
    local auth_required="${4:-yes}"
    local body_size="${5:-$NGM_DEFAULT_BODY_SIZE}"
    local auth_forward="${6:-strip}"

    ngm_validate_domain "$domain" || ngm_die "Invalid domain: $domain"
    ngm_validate_upstream "$upstream" || \
        ngm_die "Invalid upstream. Use a URL such as http://127.0.0.1:3080"
    ngm_validate_body_size "$body_size" || ngm_die "Invalid body size: $body_size"
    [[ "$auth_required" == "yes" || "$auth_required" == "no" ]] || ngm_die "Invalid auth mode."
    [[ "$auth_forward" == "strip" || "$auth_forward" == "pass" ]] || ngm_die "Invalid Authorization forwarding mode."

    if ngm_site_exists "$domain"; then
        ngm_die "Managed site already exists: $domain"
    fi

    ngm_write_site_env "$domain" "$upstream" "$auth_required" "$body_size" "$auth_forward"

    if [[ "$auth_required" == "yes" ]]; then
        [[ -n "$auth_user" ]] || \
            ngm_die "Authenticated proxies require a username."
        ngm_auth_add_impl "$domain" "$auth_user"
    fi

    ngm_render_site "$domain"
    ngm_apply_nginx

    ngm_info "Managed proxy created: ${domain} -> ${upstream}"
    if ! ngm_cert_exists "$domain"; then
        ngm_info "TLS pending. Next: nginx-manager ssl-issue ${domain} EMAIL"
    fi
}

ngm_proxy_add() {
    ngm_begin_mutation
    ngm_prepare_common

    local domain="${1:-}"
    local upstream="${2:-}"
    local user="${3:-}"

    [[ -n "$domain" && -n "$upstream" && -n "$user" ]] || \
        ngm_die "Usage: nginx-manager proxy-add DOMAIN UPSTREAM AUTH_USER"

    ngm_proxy_add_impl "$domain" "$upstream" "$user" yes "$NGM_DEFAULT_BODY_SIZE"
}

ngm_proxy_add_public() {
    ngm_begin_mutation
    ngm_prepare_common

    local domain="${1:-}"
    local upstream="${2:-}"

    [[ -n "$domain" && -n "$upstream" ]] || \
        ngm_die "Usage: nginx-manager proxy-add-public DOMAIN UPSTREAM"

    cat <<EOF
WARNING: This will create an unauthenticated public reverse proxy:
  Domain:   ${domain}
  Upstream: ${upstream}

Use this only for an application that provides its own authentication.
EOF

    local answer=""
    read -r -p "Type PUBLIC-PROXY to continue: " answer
    [[ "$answer" == "PUBLIC-PROXY" ]] || ngm_die "Cancelled."

    ngm_proxy_add_impl "$domain" "$upstream" "" no "$NGM_DEFAULT_BODY_SIZE" pass
}

ngm_proxy_add_api() {
    ngm_begin_mutation
    ngm_prepare_common

    local domain="${1:-}"
    local upstream="${2:-}"

    [[ -n "$domain" && -n "$upstream" ]] || \
        ngm_die "Usage: nginx-manager proxy-add-api DOMAIN UPSTREAM"

    cat <<EOF
API REVERSE PROXY
  Domain:   ${domain}
  Upstream: ${upstream}

Nginx edge Basic Auth will be disabled and the client Authorization header
will be preserved for the upstream application. The upstream MUST provide its
own authentication/authorization.
EOF

    local answer=""
    read -r -p "Type API-PROXY to continue: " answer
    [[ "$answer" == "API-PROXY" ]] || ngm_die "Cancelled."

    ngm_proxy_add_impl "$domain" "$upstream" "" no "$NGM_DEFAULT_BODY_SIZE" pass
}

ngm_proxy_remove() {
    ngm_begin_mutation
    ngm_prepare_common

    local domain="${1:-}"
    ngm_validate_domain "${domain,,}" || ngm_die "Usage: nginx-manager proxy-remove DOMAIN"
    domain="${domain,,}"

    ngm_site_exists "$domain" || ngm_die "Managed site not found: $domain"

    rm -f "$(ngm_site_link "$domain")" "$(ngm_site_conf "$domain")" "$(ngm_site_env "$domain")"
    rm -f "$(ngm_auth_file "$domain")"

    ngm_apply_nginx

    ngm_info "Removed Nginx managed site: $domain"
    ngm_warn "Let's Encrypt certificate was preserved. Use 'certbot certificates' to review it."
}

ngm_proxy_list() {
    echo "=== nginx-manager proxies ==="

    local domain count=0
    while IFS= read -r domain; do
        [[ -n "$domain" ]] || continue
        ((count += 1))

        ngm_load_site "$domain"

        local tls auth_users
        if ngm_cert_exists "$domain"; then
            tls="TLS"
        else
            tls="HTTP-PENDING"
        fi
        auth_users="$(ngm_auth_count "$domain")"

        printf '%-36s %-7s auth=%-3s authz=%-5s users=%-2s -> %s\n' \
            "$domain" "$tls" "$AUTH_REQUIRED" "$AUTH_FORWARD" "$auth_users" "$UPSTREAM"
    done < <(ngm_list_domains)

    (( count > 0 )) || echo "(none)"
}

ngm_proxy_show() {
    local domain="${1:-}"
    ngm_validate_domain "${domain,,}" || ngm_die "Usage: nginx-manager proxy-show DOMAIN"
    domain="${domain,,}"

    ngm_load_site "$domain"

    echo "Domain:         $DOMAIN"
    echo "Upstream:       $UPSTREAM"
    echo "Authentication: $AUTH_REQUIRED"
    echo "Authorization:  $AUTH_FORWARD"
    echo "Auth users:     $(ngm_auth_count "$domain")"
    echo "Body size:      $BODY_SIZE"
    echo "TLS:            $(ngm_cert_exists "$domain" && echo yes || echo no)"
    echo "Config:         $(ngm_site_conf "$domain")"
    echo "Enabled:        $(ngm_site_link "$domain")"
    echo
    sed -n '1,240p' "$(ngm_site_conf "$domain")"
}

ngm_proxy_set_body_size() {
    ngm_begin_mutation
    ngm_prepare_common

    local domain="${1:-}"
    local size="${2:-}"

    ngm_validate_domain "${domain,,}" || ngm_die "Usage: nginx-manager proxy-set-body DOMAIN SIZE"
    ngm_validate_body_size "$size" || ngm_die "SIZE must look like 170m, 1g, 512m."

    domain="${domain,,}"
    ngm_load_site "$domain"
    ngm_write_site_env "$domain" "$UPSTREAM" "$AUTH_REQUIRED" "$size" "$AUTH_FORWARD"
    ngm_render_site "$domain"
    ngm_apply_nginx

    ngm_info "Updated client_max_body_size for ${domain}: ${size}"
}

# -----------------------------------------------------------------------------
# TLS / Certbot
# -----------------------------------------------------------------------------

ngm_ssl_issue_impl() {
    local domain="${1,,}"
    local email="$2"

    ngm_validate_domain "$domain" || ngm_die "Invalid domain."
    ngm_validate_email "$email" || ngm_die "Invalid email address."
    ngm_site_exists "$domain" || ngm_die "Create the managed proxy first."

    ngm_render_site "$domain"
    ngm_apply_nginx

    echo
    ngm_dns_check "$domain" || \
        ngm_warn "Continuing despite DNS mismatch. HTTP-01 must still reach this server on port 80."

    ngm_log "Issuing Let's Encrypt certificate for ${domain}"

    certbot certonly \
        --webroot \
        --webroot-path "$NGM_ACME_ROOT" \
        --domain "$domain" \
        --email "$email" \
        --agree-tos \
        --non-interactive \
        --keep-until-expiring \
        --preferred-challenges http

    ngm_cert_exists "$domain" || ngm_die "Certbot returned without a usable certificate."

    ngm_render_site "$domain"
    ngm_apply_nginx

    ngm_info "HTTPS enabled: https://${domain}"
    ngm_ssl_status "$domain"
}

ngm_ssl_issue() {
    ngm_begin_mutation
    ngm_prepare_common

    local domain="${1:-}"
    local email="${2:-}"

    [[ -n "$domain" && -n "$email" ]] || \
        ngm_die "Usage: nginx-manager ssl-issue DOMAIN EMAIL"

    ngm_ssl_issue_impl "$domain" "$email"
}

ngm_ssl_renew() {
    ngm_begin_mutation
    ngm_prepare_common

    local domain="${1:-}"

    if [[ -n "$domain" ]]; then
        ngm_validate_domain "${domain,,}" || ngm_die "Invalid domain."
        certbot renew --cert-name "${domain,,}"
    else
        certbot renew
    fi

    ngm_render_all_sites
    ngm_apply_nginx
}

ngm_ssl_force_renew() {
    ngm_begin_mutation
    ngm_prepare_common

    local domain="${1:-}"
    ngm_validate_domain "${domain,,}" || \
        ngm_die "Usage: nginx-manager ssl-force-renew DOMAIN"

    domain="${domain,,}"
    ngm_site_exists "$domain" || ngm_die "Managed site not found."

    certbot renew --cert-name "$domain" --force-renewal
    ngm_render_site "$domain"
    ngm_apply_nginx
    ngm_ssl_status "$domain"
}

ngm_ssl_dry_run() {
    ngm_require_root
    certbot renew --dry-run
}

ngm_ssl_status() {
    local domain="${1:-}"

    if [[ -z "$domain" ]]; then
        certbot certificates
        return 0
    fi

    ngm_validate_domain "${domain,,}" || ngm_die "Usage: nginx-manager ssl-status [DOMAIN]"
    domain="${domain,,}"

    local cert
    cert="$(ngm_cert_fullchain "$domain")"

    if [[ ! -s "$cert" ]]; then
        echo "TLS: NOT ISSUED for $domain"
        return 1
    fi

    echo "=== TLS certificate: $domain ==="
    openssl x509 -in "$cert" -noout \
        -subject \
        -issuer \
        -serial \
        -startdate \
        -enddate \
        -fingerprint -sha256
}

ngm_ssl_days_left() {
    local domain="${1:-}"
    ngm_validate_domain "${domain,,}" || ngm_die "Usage: nginx-manager ssl-days DOMAIN"
    domain="${domain,,}"

    local cert end_epoch now_epoch
    cert="$(ngm_cert_fullchain "$domain")"
    [[ -s "$cert" ]] || ngm_die "Certificate not found: $domain"

    end_epoch="$(date -d "$(openssl x509 -in "$cert" -noout -enddate | cut -d= -f2-)" +%s)"
    now_epoch="$(date +%s)"

    printf '%d\n' "$(( (end_epoch - now_epoch) / 86400 ))"
}

# -----------------------------------------------------------------------------
# Site verification / security
# -----------------------------------------------------------------------------

ngm_upstream_http_code() {
    local upstream="$1"
    curl -sS \
        --connect-timeout 2 \
        --max-time 8 \
        -o /dev/null \
        -w '%{http_code}' \
        "$upstream/" 2>/dev/null || true
}

ngm_site_verify() {
    ngm_require_root

    local domain="${1:-}"
    ngm_validate_domain "${domain,,}" || ngm_die "Usage: nginx-manager site-verify DOMAIN"
    domain="${domain,,}"

    ngm_load_site "$domain"

    echo "=== Verify ${domain} ==="

    echo "[1/7] Managed config"
    [[ -f "$(ngm_site_conf "$domain")" ]] || ngm_die "Nginx site config missing."
    [[ -L "$(ngm_site_link "$domain")" ]] || ngm_die "Nginx site is not enabled."

    echo "[2/7] Nginx syntax"
    nginx -t >/dev/null

    echo "[3/7] Upstream"
    local upstream_code
    upstream_code="$(ngm_upstream_http_code "$UPSTREAM")"
    [[ "$upstream_code" =~ ^[1-5][0-9][0-9]$ ]] || ngm_die "Upstream is unreachable: $UPSTREAM"
    ngm_info "Upstream HTTP: ${upstream_code}"

    echo "[4/7] Authentication"
    if [[ "$AUTH_REQUIRED" == "yes" ]]; then
        (( $(ngm_auth_count "$domain") > 0 )) || ngm_die "Authentication required but no users exist."
        ngm_secure_auth_file "$domain"
    fi

    echo "[5/7] Certificate"
    ngm_cert_exists "$domain" || ngm_die "TLS certificate is not installed."
    local days
    days="$(ngm_ssl_days_left "$domain")"
    (( days > 7 )) || ngm_warn "Certificate expires in ${days} day(s)."
    ngm_info "Certificate days remaining: ${days}"

    echo "[6/7] Local HTTPS edge"
    local https_code
    https_code="$(
        curl -sk \
            --resolve "${domain}:443:127.0.0.1" \
            --connect-timeout 2 \
            --max-time 8 \
            -o /dev/null \
            -w '%{http_code}' \
            "https://${domain}/" 2>/dev/null || true
    )"

    if [[ "$AUTH_REQUIRED" == "yes" ]]; then
        [[ "$https_code" == "401" ]] || \
            ngm_die "Expected HTTP 401 without credentials; got ${https_code:-none}."
        ngm_info "Anonymous HTTPS access blocked: HTTP 401"
    else
        [[ "$https_code" =~ ^[1-5][0-9][0-9]$ ]] || ngm_die "Local HTTPS request failed."
        ngm_info "Public HTTPS response: HTTP ${https_code}"
    fi

    echo "[7/7] HTTP redirect"
    local http_code
    http_code="$(
        curl -sS \
            --resolve "${domain}:80:127.0.0.1" \
            --connect-timeout 2 \
            --max-time 8 \
            -o /dev/null \
            -w '%{http_code}' \
            "http://${domain}/" 2>/dev/null || true
    )"
    [[ "$http_code" =~ ^30[1278]$ ]] || ngm_die "Expected HTTP -> HTTPS redirect; got ${http_code:-none}."
    ngm_info "HTTP redirect: ${http_code}"

    echo
    echo "SITE VERIFIED: ${domain}"
}

ngm_verify_loopback_port() {
    local name="$1"
    local port="$2"
    local endpoints=""

    endpoints="$(
        {
            ss -H -lnt4 "( sport = :${port} )" 2>/dev/null || true
            ss -H -lnt6 "( sport = :${port} )" 2>/dev/null || true
        } | awk '{print $4}' | sed '/^[[:space:]]*$/d' | sort -u
    )"

    [[ -n "$endpoints" ]] || return 1

    local ep
    while IFS= read -r ep; do
        [[ -n "$ep" ]] || continue
        case "$ep" in
            "127.0.0.1:${port}"|"[::1]:${port}"|"::1:${port}")
                ;;
            *)
                ngm_die "Unsafe ${name} listener: ${ep}"
                ;;
        esac
    done <<<"$endpoints"

    printf '%s\n' "$endpoints"
}

ngm_security_check() {
    ngm_require_root

    echo "=== nginx-manager security check ==="

    echo "[1/8] Nginx service"
    systemctl is-active --quiet nginx.service || ngm_die "nginx.service is inactive."

    echo "[2/8] Nginx syntax"
    nginx -t >/dev/null

    echo "[3/8] Version hiding"
    grep -Eq '^[[:space:]]*server_tokens[[:space:]]+off;' "$NGM_NGINX_GLOBAL" || \
        ngm_die "server_tokens off is missing."

    echo "[4/8] Managed authentication"
    local domain
    while IFS= read -r domain; do
        [[ -n "$domain" ]] || continue
        ngm_load_site "$domain"

        if [[ "$AUTH_REQUIRED" == "yes" ]]; then
            (( $(ngm_auth_count "$domain") > 0 )) || \
                ngm_die "Authenticated site has no users: $domain"
        else
            ngm_warn "Unauthenticated managed proxy: $domain"
        fi
    done < <(ngm_list_domains)

    echo "[5/8] Certificate keys"
    if [[ -d /etc/letsencrypt/live ]]; then
        find /etc/letsencrypt/live -type l -name privkey.pem -print >/dev/null 2>&1 || true
    fi

    echo "[6/8] Application loopback exposure"
    local hs="" es="" os=""
    hs="$(ngm_verify_loopback_port "Harness" "$NGM_HARNESS_PORT" || true)"
    es="$(ngm_verify_loopback_port "Hermes" "$NGM_HERMES_PORT" || true)"
    os="$(ngm_verify_loopback_port "Ollama" "$NGM_OLLAMA_PORT" || true)"

    if [[ -n "$hs" ]]; then
        ngm_info "Harness loopback listener(s): $(tr '\n' ' ' <<<"$hs" | xargs)"
    fi
    if [[ -n "$es" ]]; then
        ngm_info "Hermes loopback listener(s): $(tr '\n' ' ' <<<"$es" | xargs)"
    fi
    if [[ -n "$os" ]]; then
        ngm_info "Ollama loopback listener(s): $(tr '\n' ' ' <<<"$os" | xargs)"
    fi

    echo "[7/8] Renewal automation"
    if systemctl is-enabled --quiet certbot.timer 2>/dev/null; then
        :
    elif systemctl is-enabled --quiet nginx-manager-certbot-renew.timer 2>/dev/null; then
        :
    else
        ngm_die "No enabled Certbot renewal timer."
    fi

    echo "[8/8] Default site"
    [[ ! -e /etc/nginx/sites-enabled/default ]] || ngm_die "Ubuntu default site is enabled."

    echo
    echo "NGINX SECURITY: VERIFIED"
}

ngm_verify() {
    ngm_require_root
    ngm_lock
    ngm_require_ubuntu_2404

    echo "=== nginx-manager verification ==="

    echo "[1/9] Canonical manager"
    [[ "$(ngm_canonical_version)" == "$NGM_VERSION" ]] || \
        ngm_die "Canonical manager is $(ngm_canonical_version), expected ${NGM_VERSION}."

    echo "[2/9] Required packages"
    ngm_require_cmd nginx
    ngm_require_cmd certbot
    ngm_require_cmd htpasswd
    ngm_require_cmd curl
    ngm_require_cmd openssl

    echo "[3/9] Nginx configuration"
    nginx -t >/dev/null

    echo "[4/9] Nginx service"
    systemctl is-active --quiet nginx.service || ngm_die "nginx.service is inactive."

    echo "[5/9] Managed sites / listeners"
    local domain site_count=0 tls_count=0
    while IFS= read -r domain; do
        [[ -n "$domain" ]] || continue
        ((site_count += 1))
        ngm_site_exists "$domain" || ngm_die "Site metadata missing: $domain"
        [[ -f "$(ngm_site_conf "$domain")" ]] || ngm_die "Site config missing: $domain"
        [[ -L "$(ngm_site_link "$domain")" ]] || ngm_die "Site not enabled: $domain"

        if ngm_cert_exists "$domain"; then
            ((tls_count += 1))
        fi
    done < <(ngm_list_domains)

    if (( site_count > 0 )); then
        ss -H -lnt '( sport = :80 )' | grep -q . || \
            ngm_die "Managed sites exist but Nginx is not listening on port 80."
    else
        ngm_warn "No managed proxy sites exist yet."
    fi

    if (( tls_count > 0 )); then
        ss -H -lnt '( sport = :443 )' | grep -q . || \
            ngm_die "TLS sites exist but Nginx is not listening on port 443."
    fi

    ngm_info "Managed sites: ${site_count}; TLS sites: ${tls_count}"

    echo "[6/9] Global proxy policy"
    [[ -f "$NGM_NGINX_GLOBAL" ]] || ngm_die "nginx-manager global config is missing."
    grep -Eq '^[[:space:]]*server_tokens[[:space:]]+off;' "$NGM_NGINX_GLOBAL" || \
        ngm_die "server_tokens off is missing."

    echo "[7/9] Renewal hook / timer"
    [[ -x "$NGM_RENEW_HOOK" ]] || ngm_die "Certbot deploy hook is missing."
    if systemctl is-enabled --quiet certbot.timer 2>/dev/null; then
        ngm_info "Renewal timer: certbot.timer"
    elif systemctl is-enabled --quiet nginx-manager-certbot-renew.timer 2>/dev/null; then
        ngm_info "Renewal timer: nginx-manager-certbot-renew.timer"
    else
        ngm_die "No Certbot renewal timer enabled."
    fi

    echo "[8/9] Security"
    ngm_security_check >/dev/null

    echo "[9/9] Site-level verification"
    while IFS= read -r domain; do
        [[ -n "$domain" ]] || continue
        if ngm_cert_exists "$domain"; then
            ngm_site_verify "$domain" >/dev/null
        else
            ngm_warn "TLS pending: $domain"
        fi
    done < <(ngm_list_domains)

    echo
    echo "NGINX MANAGER: VERIFIED"
    echo "Manager:        ${NGM_VERSION}"
    echo "Nginx:          $(nginx -v 2>&1 | sed 's#nginx version: ##')"
    echo "Certbot:        $(certbot --version 2>&1 | head -1)"
    echo "Server IP:      ${NGM_DEFAULT_SERVER_IP}"
    echo "Managed sites:  ${site_count}"
}

# -----------------------------------------------------------------------------
# Harness convenience integration
# -----------------------------------------------------------------------------

ngm_disable_legacy_harness_relay() {
    local legacy="/etc/nginx/conf.d/deepseek-harness-relay.conf"

    if [[ -f "$legacy" ]]; then
        local dest="${NGM_DISABLED_DIR}/deepseek-harness-relay.$(date -u +%Y%m%dT%H%M%SZ).conf"
        mv "$legacy" "$dest"
        ngm_warn "Disabled obsolete Plesk relay config: $legacy"
        ngm_info "Preserved at: $dest"
    fi

    if systemctl cat deepseek-harness-tunnel.service >/dev/null 2>&1; then
        systemctl disable --now deepseek-harness-tunnel.service >/dev/null 2>&1 || true
        ngm_info "Disabled obsolete DeepSeek Harness Plesk tunnel service."
    fi
}

ngm_harness_setup() {
    ngm_begin_mutation
    ngm_prepare_common

    local domain="${1:-}"
    local email="${2:-}"
    local user="${3:-harnessadmin}"

    ngm_validate_domain "${domain,,}" || \
        ngm_die "Usage: nginx-manager harness-setup DOMAIN EMAIL [AUTH_USER]"
    ngm_validate_email "$email" || ngm_die "Invalid email address."
    ngm_validate_username "$user" || ngm_die "Invalid authentication username."

    domain="${domain,,}"

    ngm_log "Checking local DeepSeek Harness"
    local code
    code="$(ngm_upstream_http_code "$NGM_HARNESS_UPSTREAM")"
    [[ "$code" =~ ^[1-5][0-9][0-9]$ ]] || \
        ngm_die "Harness is not reachable at ${NGM_HARNESS_UPSTREAM}"
    ngm_info "Harness local HTTP: ${code}"

    ngm_disable_legacy_harness_relay

    if ! ngm_site_exists "$domain"; then
        ngm_proxy_add_impl \
            "$domain" \
            "$NGM_HARNESS_UPSTREAM" \
            "$user" \
            yes \
            "$NGM_DEFAULT_BODY_SIZE"
    else
        ngm_info "Managed site already exists: $domain"
        ngm_load_site "$domain"
        [[ "$UPSTREAM" == "$NGM_HARNESS_UPSTREAM" ]] || \
            ngm_die "Existing site uses a different upstream: $UPSTREAM"

        if [[ "$AUTH_REQUIRED" != "yes" ]]; then
            ngm_warn "Re-enabling authentication for Harness public edge."
            ngm_write_site_env "$domain" "$UPSTREAM" yes "$BODY_SIZE" strip
        fi

        local auth_file
        auth_file="$(ngm_auth_file "$domain")"
        if [[ ! -f "$auth_file" ]] || ! grep -Fq "${user}:" "$auth_file"; then
            ngm_auth_add_impl "$domain" "$user"
        fi

        ngm_render_site "$domain"
        ngm_apply_nginx
    fi

    if [[ -x "$NGM_HARNESS_MANAGER" ]]; then
        ngm_log "Registering trusted public host with harness-manager"
        "$NGM_HARNESS_MANAGER" trusted-add "$domain"
        "$NGM_HARNESS_MANAGER" restart
    else
        ngm_warn "harness-manager not found; ensure Harness trusts ${domain}."
    fi

    if ! ngm_cert_exists "$domain"; then
        ngm_ssl_issue_impl "$domain" "$email"
    else
        ngm_info "TLS certificate already exists for ${domain}."
        ngm_render_site "$domain"
        ngm_apply_nginx
    fi

    ngm_site_verify "$domain"

    echo
    echo "HARNESS PUBLIC EDGE: READY"
    echo "URL:       https://${domain}"
    echo "Auth user: ${user}"
    echo "Upstream:  ${NGM_HARNESS_UPSTREAM}"
    echo
    echo "Privileged Harness settings remain intentionally local-only."
    echo "Use harness-manager local-access for the SSH localhost tunnel."
}

ngm_harness_check() {
    ngm_require_root

    echo "=== Harness edge check ==="

    local hs os
    hs="$(ngm_verify_loopback_port "Harness" "$NGM_HARNESS_PORT")" || \
        ngm_die "Harness is not listening on a loopback address."
    os="$(ngm_verify_loopback_port "Ollama" "$NGM_OLLAMA_PORT")" || \
        ngm_die "Ollama is not listening on a loopback address."

    echo "Harness listener(s):"
    printf '%s\n' "$hs"
    echo
    echo "Ollama listener(s):"
    printf '%s\n' "$os"

    curl -fsS --connect-timeout 2 --max-time 8 \
        "$NGM_HARNESS_UPSTREAM/" >/dev/null || ngm_die "Harness HTTP health failed."
    curl -fsS --connect-timeout 2 --max-time 8 \
        "http://127.0.0.1:${NGM_OLLAMA_PORT}/v1/models" >/dev/null || \
        ngm_die "Ollama OpenAI-compatible API failed."

    echo
    echo "HARNESS LOCAL ISOLATION: VERIFIED"
}


# -----------------------------------------------------------------------------
# Hermes Agent convenience integration
# -----------------------------------------------------------------------------

ngm_hermes_setup() {
    ngm_begin_mutation
    ngm_prepare_common

    local domain="${1:-}"
    local email="${2:-}"
    local user="${3:-hermesadmin}"

    ngm_validate_domain "${domain,,}" || \
        ngm_die "Usage: nginx-manager hermes-setup DOMAIN EMAIL [AUTH_USER]"
    ngm_validate_email "$email" || ngm_die "Invalid email address."
    ngm_validate_username "$user" || ngm_die "Invalid authentication username."

    domain="${domain,,}"

    ngm_log "Checking local Hermes Dashboard"

    local listeners=""
    listeners="$(ngm_verify_loopback_port "Hermes" "$NGM_HERMES_PORT")" || \
        ngm_die "Hermes Dashboard must listen only on loopback port ${NGM_HERMES_PORT}."
    ngm_info "Hermes listener(s): $(tr '\n' ' ' <<<"$listeners" | xargs)"

    curl -fsS \
        --connect-timeout 2 \
        --max-time 8 \
        "${NGM_HERMES_UPSTREAM}/api/status" >/dev/null || \
        ngm_die "Hermes Dashboard health failed at ${NGM_HERMES_UPSTREAM}/api/status"

    if [[ -x "$NGM_HERMES_MANAGER" ]]; then
        "$NGM_HERMES_MANAGER" verify >/dev/null || \
            ngm_die "hermes-manager verification failed."
    else
        ngm_warn "hermes-manager not found; relying on local dashboard health only."
    fi

    if ! ngm_site_exists "$domain"; then
        ngm_proxy_add_impl \
            "$domain" \
            "$NGM_HERMES_UPSTREAM" \
            "$user" \
            yes \
            "$NGM_DEFAULT_BODY_SIZE"
    else
        ngm_info "Managed site already exists: $domain"
        ngm_load_site "$domain"

        [[ "$UPSTREAM" == "$NGM_HERMES_UPSTREAM" ]] || \
            ngm_die "Existing site uses a different upstream: $UPSTREAM"

        if [[ "$AUTH_REQUIRED" != "yes" ]]; then
            ngm_warn "Re-enabling authentication for Hermes Dashboard."
            ngm_write_site_env "$domain" "$UPSTREAM" yes "$BODY_SIZE" strip
        fi

        local auth_file
        auth_file="$(ngm_auth_file "$domain")"
        if [[ ! -f "$auth_file" ]] || ! grep -Fq "${user}:" "$auth_file"; then
            ngm_auth_add_impl "$domain" "$user"
        fi

        ngm_render_site "$domain"
        ngm_apply_nginx
    fi

    if ! ngm_cert_exists "$domain"; then
        ngm_ssl_issue_impl "$domain" "$email"
    else
        ngm_info "TLS certificate already exists for ${domain}."
        ngm_render_site "$domain"
        ngm_apply_nginx
    fi

    ngm_site_verify "$domain"

    echo
    echo "HERMES DASHBOARD EDGE: READY"
    echo "URL:       https://${domain}"
    echo "Auth user: ${user}"
    echo "Upstream:  ${NGM_HERMES_UPSTREAM}"
    echo
    echo "Hermes itself remains loopback-only on 127.0.0.1:${NGM_HERMES_PORT}."
}

ngm_hermes_check() {
    ngm_require_root

    echo "=== Hermes Dashboard edge check ==="

    local listeners
    listeners="$(ngm_verify_loopback_port "Hermes" "$NGM_HERMES_PORT")" || \
        ngm_die "Hermes Dashboard is not listening on loopback port ${NGM_HERMES_PORT}."

    echo "Hermes listener(s):"
    printf '%s\n' "$listeners"

    curl -fsS \
        --connect-timeout 2 \
        --max-time 8 \
        "${NGM_HERMES_UPSTREAM}/api/status" >/dev/null || \
        ngm_die "Hermes Dashboard API health failed."

    if [[ -x "$NGM_HERMES_MANAGER" ]]; then
        "$NGM_HERMES_MANAGER" verify >/dev/null || \
            ngm_die "hermes-manager verification failed."
    fi

    echo
    echo "HERMES DASHBOARD LOCAL ISOLATION: VERIFIED"
}

# -----------------------------------------------------------------------------
# Lifecycle / repair / update
# -----------------------------------------------------------------------------

ngm_install() {
    ngm_begin_mutation

    ngm_log "Installing nginx-manager production edge"
    ngm_prepare_common
    ngm_render_all_sites
    ngm_apply_nginx

    ngm_log "Installation complete"
    echo
    echo "Next for DeepSeek Harness:"
    echo "  nginx-manager harness-setup agent.simhaonline.ai EMAIL harnessadmin"
}

ngm_repair() {
    ngm_begin_mutation

    ngm_log "Repairing Nginx / Certbot managed configuration"
    ngm_prepare_common

    local domain
    while IFS= read -r domain; do
        [[ -n "$domain" ]] || continue
        if [[ -f "$(ngm_auth_file "$domain")" ]]; then
            ngm_secure_auth_file "$domain"
        fi
    done < <(ngm_list_domains)

    ngm_render_all_sites
    ngm_apply_nginx

    ngm_verify
}

ngm_update() {
    ngm_begin_mutation

    ngm_log "Updating Nginx / Certbot packages"
    ngm_apt update
    ngm_apt install -y --only-upgrade \
        nginx \
        nginx-common \
        certbot \
        apache2-utils \
        openssl \
        ca-certificates

    ngm_prepare_common
    ngm_render_all_sites
    ngm_apply_nginx
    ngm_verify
}

ngm_reinstall() {
    ngm_begin_mutation

    ngm_log "Reinstalling Nginx / Certbot packages without deleting managed configuration"
    ngm_apt update
    ngm_apt install -y --reinstall \
        nginx \
        nginx-common \
        certbot \
        apache2-utils

    ngm_prepare_common
    ngm_render_all_sites
    ngm_apply_nginx
    ngm_verify
}

# -----------------------------------------------------------------------------
# Nginx service / status / logs
# -----------------------------------------------------------------------------

ngm_start() {
    ngm_require_root
    systemctl unmask nginx.service >/dev/null 2>&1 || true
    systemctl enable --now nginx.service
    nginx -t
}

ngm_stop() {
    ngm_require_root
    systemctl stop nginx.service
}

ngm_restart() {
    ngm_require_root
    nginx -t
    systemctl restart nginx.service
    systemctl is-active --quiet nginx.service || ngm_die "Nginx restart failed."
}

ngm_reload() {
    ngm_require_root
    nginx -t
    systemctl reload nginx.service
}

ngm_status() {
    ngm_require_root

    echo "=== nginx-manager ==="
    echo "Manager:   $NGM_VERSION"
    echo "Canonical: $(ngm_canonical_version)"
    echo "Server IP: $NGM_DEFAULT_SERVER_IP"
    echo "Nginx:     $(nginx -v 2>&1 | sed 's#nginx version: ##' || true)"
    echo "Certbot:   $(certbot --version 2>&1 | head -1 || true)"
    echo

    systemctl --no-pager --full status nginx.service 2>/dev/null | sed -n '1,24p' || true
    echo

    echo "=== Listeners ==="
    ss -H -lntp 2>/dev/null | awk '$4 ~ /:(80|443|3080|9119|11434|13080)$/ {print}' || true
    echo

    ngm_proxy_list
    echo

    echo "=== Renewal timers ==="
    systemctl list-timers --all --no-pager 2>/dev/null | \
        grep -E 'certbot|nginx-manager-certbot' || true
}

ngm_logs() {
    ngm_require_root
    local lines="${1:-$NGM_LOG_LINES}"
    [[ "$lines" =~ ^[1-9][0-9]*$ ]] || ngm_die "LINES must be a positive integer."
    (( lines <= 5000 )) || ngm_die "LINES is capped at 5000."
    journalctl -u nginx.service -n "$lines" --no-pager
}

ngm_follow() {
    ngm_require_root
    journalctl -u nginx.service -f
}

ngm_access_logs() {
    ngm_require_root
    local domain="${1:-}"
    ngm_validate_domain "${domain,,}" || ngm_die "Usage: nginx-manager access-logs DOMAIN"

    tail -n "${NGM_LOG_LINES}" \
        "/var/log/nginx/${domain,,}.ssl.access.log" \
        "/var/log/nginx/${domain,,}.ssl.error.log" 2>/dev/null || true
}

ngm_doctor() {
    ngm_require_root

    echo "=== nginx-manager doctor ==="
    echo "Running manager:   $NGM_VERSION"
    echo "Canonical manager: $(ngm_canonical_version)"
    echo

    echo "=== OS ==="
    grep -E '^(PRETTY_NAME|VERSION_ID)=' /etc/os-release || true
    echo

    echo "=== Versions ==="
    nginx -v 2>&1 || true
    certbot --version 2>&1 || true
    openssl version 2>&1 || true
    echo

    echo "=== Nginx syntax ==="
    nginx -t 2>&1 || true
    echo

    echo "=== Nginx service ==="
    systemctl --no-pager --full status nginx.service 2>/dev/null | sed -n '1,32p' || true
    echo

    echo "=== Managed sites ==="
    ngm_proxy_list || true
    echo

    echo "=== Listeners ==="
    ss -H -lntp 2>/dev/null | grep -E ':(80|443|3080|9119|11434|13080)\b' || true
    echo

    echo "=== Certificates ==="
    certbot certificates 2>/dev/null || true
    echo

    echo "=== Renewal timers ==="
    systemctl list-timers --all --no-pager 2>/dev/null | \
        grep -E 'certbot|nginx-manager-certbot' || true
    echo

    echo "=== Recent Nginx errors ==="
    tail -n 80 /var/log/nginx/error.log 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# Firewall helpers
# -----------------------------------------------------------------------------

ngm_firewall_status() {
    if command -v ufw >/dev/null 2>&1; then
        ufw status verbose
    else
        echo "UFW is not installed."
    fi
}

ngm_firewall_open() {
    ngm_require_root

    command -v ufw >/dev/null 2>&1 || {
        ngm_apt update
        ngm_apt install -y ufw
    }

    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp

    echo
    echo "Rules added. nginx-manager does NOT automatically enable UFW."
    echo "Review first:"
    echo "  ufw status numbered"
    echo
    echo "If correct, enable explicitly:"
    echo "  ufw enable"
}

# -----------------------------------------------------------------------------
# Backup / restore information
# -----------------------------------------------------------------------------

ngm_backup() {
    ngm_begin_mutation

    local out="${1:-/root/nginx-manager-backup-$(date -u +%Y%m%dT%H%M%SZ).tar.gz}"
    [[ "$out" == /* ]] || ngm_die "Backup path must be absolute."

    local items=()

    [[ -d "$NGM_CONFIG" ]] && items+=("${NGM_CONFIG#/}")
    [[ -d /etc/nginx ]] && items+=("etc/nginx")
    [[ -d /etc/letsencrypt ]] && items+=("etc/letsencrypt")

    tar --acls --xattrs --numeric-owner -C / -czf "$out" "${items[@]}"
    chown root:root "$out"
    chmod 0600 "$out"

    ngm_info "Backup created: $out"
}

ngm_version() {
    echo "nginx-manager $NGM_VERSION"
    echo "canonical-manager $(ngm_canonical_version)"

    if command -v nginx >/dev/null 2>&1; then
        nginx -v 2>&1 | sed 's#nginx version: #nginx #'
    fi
    if command -v certbot >/dev/null 2>&1; then
        certbot --version 2>&1 | head -1
    fi
}

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------

ngm_help() {
    cat <<EOF
nginx-manager v${NGM_VERSION}
Ubuntu 24.04 LTS

Production Nginx / Certbot reverse-proxy manager.

Core lifecycle:
  install
  repair
  update
  reinstall

Nginx service:
  start
  stop
  restart
  reload
  status
  verify
  security-check
  doctor
  logs [LINES]
  follow

Reverse proxies:
  proxy-add DOMAIN UPSTREAM AUTH_USER
  proxy-add-public DOMAIN UPSTREAM
  proxy-add-api DOMAIN UPSTREAM
  proxy-remove DOMAIN
  proxy-list
  proxy-show DOMAIN
  proxy-set-body DOMAIN SIZE
  site-verify DOMAIN

Authentication:
  auth-add DOMAIN USER
  auth-delete DOMAIN USER
  auth-list DOMAIN

TLS / Certbot:
  ssl-issue DOMAIN EMAIL
  ssl-renew [DOMAIN]
  ssl-force-renew DOMAIN
  ssl-dry-run
  ssl-status [DOMAIN]
  ssl-days DOMAIN
  dns-check DOMAIN

DeepSeek Harness shortcut:
  harness-setup DOMAIN EMAIL [AUTH_USER]
  harness-check

Hermes Agent shortcut:
  hermes-setup DOMAIN EMAIL [AUTH_USER]
  hermes-check

Firewall helpers:
  firewall-status
  firewall-open

Operations:
  access-logs DOMAIN
  backup [ABSOLUTE_FILE]
  version
  help

Recommended Harness deployment:
  nginx-manager install
  nginx-manager harness-setup agent.simhaonline.ai EMAIL harnessadmin
  nginx-manager verify

Recommended Hermes Dashboard deployment:
  nginx-manager hermes-setup hermes.example.com EMAIL hermesadmin
  nginx-manager hermes-check
  nginx-manager verify

The Harness shortcut creates:

  Internet
     |
     | HTTPS :443 + Basic Auth
     v
  Nginx on ${NGM_DEFAULT_SERVER_IP}
     |
     v
  ${NGM_HARNESS_UPSTREAM}

Security defaults:
  - Reverse proxies require Basic Auth unless proxy-add-public/proxy-add-api is explicitly used.
  - proxy-add-api preserves the client Authorization header and therefore requires upstream application authentication.
  - Certbot uses HTTP-01 webroot and does not rewrite managed Nginx configs.
  - HTTP redirects to HTTPS after a certificate is installed.
  - TLS 1.2/1.3 only.
  - HSTS is enabled on HTTPS.
  - Edge Basic-Auth credentials are stripped for protected proxy-add/Harness/Hermes sites; API/public modes preserve application Authorization.
  - WebSocket and long-running streaming proxy support is enabled.
  - Ubuntu default Nginx site is disabled.
  - Harness, Hermes Dashboard and Ollama are expected to remain loopback-only.
  - Dedicated Hermes setup requires Basic Auth and verifies /api/status before TLS issuance.
EOF
}

# -----------------------------------------------------------------------------
# Dispatch
# -----------------------------------------------------------------------------

ngm_main() {
    local cmd="${1:-help}"

    case "$cmd" in
        install) ngm_install ;;
        repair) ngm_repair ;;
        update) ngm_update ;;
        reinstall) ngm_reinstall ;;

        start) ngm_start ;;
        stop) ngm_stop ;;
        restart) ngm_restart ;;
        reload) ngm_reload ;;
        status) ngm_status ;;
        verify) ngm_verify ;;
        security-check) ngm_security_check ;;
        doctor) ngm_doctor ;;
        logs)
            shift
            ngm_logs "${1:-$NGM_LOG_LINES}"
            ;;
        follow) ngm_follow ;;

        proxy-add)
            shift
            ngm_proxy_add "${1:-}" "${2:-}" "${3:-}"
            ;;
        proxy-add-public)
            shift
            ngm_proxy_add_public "${1:-}" "${2:-}"
            ;;
        proxy-add-api)
            shift
            ngm_proxy_add_api "${1:-}" "${2:-}"
            ;;
        proxy-remove)
            shift
            ngm_proxy_remove "${1:-}"
            ;;
        proxy-list) ngm_proxy_list ;;
        proxy-show)
            shift
            ngm_proxy_show "${1:-}"
            ;;
        proxy-set-body)
            shift
            ngm_proxy_set_body_size "${1:-}" "${2:-}"
            ;;
        site-verify)
            shift
            ngm_site_verify "${1:-}"
            ;;

        auth-add)
            shift
            ngm_auth_add "${1:-}" "${2:-}"
            ;;
        auth-delete|auth-remove)
            shift
            ngm_auth_delete "${1:-}" "${2:-}"
            ;;
        auth-list)
            shift
            ngm_auth_list "${1:-}"
            ;;

        ssl-issue)
            shift
            ngm_ssl_issue "${1:-}" "${2:-}"
            ;;
        ssl-renew)
            shift
            ngm_ssl_renew "${1:-}"
            ;;
        ssl-force-renew)
            shift
            ngm_ssl_force_renew "${1:-}"
            ;;
        ssl-dry-run) ngm_ssl_dry_run ;;
        ssl-status)
            shift
            ngm_ssl_status "${1:-}"
            ;;
        ssl-days)
            shift
            ngm_ssl_days_left "${1:-}"
            ;;
        dns-check)
            shift
            ngm_dns_check "${1:-}"
            ;;

        harness-setup)
            shift
            ngm_harness_setup "${1:-}" "${2:-}" "${3:-harnessadmin}"
            ;;
        harness-check) ngm_harness_check ;;

        hermes-setup)
            shift
            ngm_hermes_setup "${1:-}" "${2:-}" "${3:-hermesadmin}"
            ;;
        hermes-check) ngm_hermes_check ;;

        firewall-status) ngm_firewall_status ;;
        firewall-open) ngm_firewall_open ;;

        access-logs)
            shift
            ngm_access_logs "${1:-}"
            ;;
        backup)
            shift
            ngm_backup "${1:-}"
            ;;
        version) ngm_version ;;
        help|-h|--help) ngm_help ;;
        *)
            ngm_help >&2
            ngm_die "Unknown command: $cmd"
            ;;
    esac
}

ngm_main "$@"
