#!/usr/bin/env bash
set -euo pipefail

# Mattermost on a bare server — interactive installer (Ubuntu 22.04+ friendly)
# - Installs Docker Engine + Compose plugin if missing
# - Writes docker-compose.yml, .env, Caddyfile (optional)
# - Starts stack
#
# Run:
#   sudo bash install-mattermost.sh

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
info() { printf "• %s\n" "$*"; }
warn() { printf "\033[33m! %s\033[0m\n" "$*"; }
err()  { printf "\033[31m✗ %s\033[0m\n" "$*"; }

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "Run as root: sudo bash $0"
    exit 1
  fi
}

cmd_exists() { command -v "$1" >/dev/null 2>&1; }

detect_os() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "${ID:-unknown}:${VERSION_ID:-unknown}"
  else
    echo "unknown:unknown"
  fi
}

pkg_mgr() {
  if cmd_exists apt-get; then echo "apt"; return; fi
  if cmd_exists dnf; then echo "dnf"; return; fi
  if cmd_exists yum; then echo "yum"; return; fi
  echo "none"
}

read_default() {
  local prompt="$1" default="$2" var
  read -r -p "${prompt} [${default}]: " var
  echo "${var:-$default}"
}

read_secret() {
  local prompt="$1" a b
  while true; do
    read -r -s -p "${prompt}: " a; echo
    read -r -s -p "Confirm ${prompt}: " b; echo
    [[ -n "$a" ]] || { warn "Value cannot be empty."; continue; }
    [[ "$a" == "$b" ]] || { warn "Values do not match. Try again."; continue; }
    echo "$a"; return 0
  done
}

yesno() {
  local prompt="$1" default="${2:-y}" ans hint="[y/N]"
  [[ "$default" =~ ^[Yy]$ ]] && hint="[Y/n]"
  read -r -p "${prompt} ${hint}: " ans
  ans="${ans:-$default}"
  [[ "$ans" =~ ^[Yy]$ ]]
}

gen_pw() {
  # Prefer openssl (stable, locale-independent)
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 24 | tr -d '\n'
    return 0
  fi
  # Fallback: alphanumerics only (avoid locale/range issues)
  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32
}

ensure_basics() {
  local pm; pm="$(pkg_mgr)"
  case "$pm" in
    apt)
      info "Installing base packages (curl, ca-certificates, gnupg, lsb-release, mawk, openssl)..."
      apt-get update -y
      DEBIAN_FRONTEND=noninteractive apt-get install -y \
        ca-certificates curl gnupg lsb-release apt-transport-https \
        mawk sed coreutils openssl
      ;;
    dnf)
      info "Installing base packages (curl, ca-certificates, gnupg2, openssl)..."
      dnf -y install ca-certificates curl gnupg2 sed gawk coreutils openssl || true
      ;;
    yum)
      info "Installing base packages (curl, ca-certificates, gnupg2, openssl)..."
      yum -y install ca-certificates curl gnupg2 sed gawk coreutils openssl || true
      ;;
    *)
      err "No supported package manager found (apt/dnf/yum)."
      exit 1
      ;;
  esac
}

install_docker_apt() {
  info "Installing Docker Engine (apt)..."
  install -m 0755 -d /etc/apt/keyrings

  local distro codename
  distro="$(. /etc/os-release; echo "$ID")"
  codename="$(. /etc/os-release; echo "${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null || echo jammy)}")"

  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL "https://download.docker.com/linux/${distro}/gpg" \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  cat >/etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${distro} ${codename} stable
EOF

  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  systemctl enable --now docker
}

install_docker_rhel() {
  info "Installing Docker Engine (dnf/yum)..."
  local pm; pm="$(pkg_mgr)"
  if [[ "$pm" == "dnf" ]]; then
    dnf -y install dnf-plugins-core || true
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  else
    yum -y install yum-utils || true
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi
  systemctl enable --now docker
}

ensure_docker() {
  if cmd_exists docker && docker info >/dev/null 2>&1; then
    info "Docker is already installed and running."
    return 0
  fi

  warn "Docker is missing or not running."
  if ! yesno "Install Docker Engine + Compose plugin now?" "y"; then
    err "Cannot continue without Docker."
    exit 1
  fi

  local pm; pm="$(pkg_mgr)"
  case "$pm" in
    apt) install_docker_apt ;;
    dnf|yum) install_docker_rhel ;;
    *) err "Unsupported package manager; install Docker manually."; exit 1 ;;
  esac

  docker info >/dev/null 2>&1 || { err "Docker installed but daemon not reachable."; exit 1; }
  info "Docker installation complete."
}

compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    echo "docker compose"; return 0
  fi
  if cmd_exists docker-compose; then
    echo "docker-compose"; return 0
  fi
  err "Docker Compose not found."
  exit 1
}

ensure_firewall_ports() {
  local want_https="$1"
  if cmd_exists ufw && ufw status >/dev/null 2>&1; then
    info "Configuring UFW rules (best-effort)..."
    ufw allow 8065/tcp >/dev/null 2>&1 || true
    if [[ "$want_https" == "yes" ]]; then
      ufw allow 80/tcp >/dev/null 2>&1 || true
      ufw allow 443/tcp >/dev/null 2>&1 || true
    fi
    return 0
  fi

  if cmd_exists firewall-cmd && firewall-cmd --state >/dev/null 2>&1; then
    info "Configuring firewalld rules (best-effort)..."
    firewall-cmd --permanent --add-port=8065/tcp >/dev/null 2>&1 || true
    if [[ "$want_https" == "yes" ]]; then
      firewall-cmd --permanent --add-service=http >/dev/null 2>&1 || true
      firewall-cmd --permanent --add-service=https >/dev/null 2>&1 || true
    fi
    firewall-cmd --reload >/dev/null 2>&1 || true
    return 0
  fi

  warn "No firewall tool detected (ufw/firewalld). Ensure ports are open: 8065 (and 80/443 for HTTPS)."
}

write_files() {
  local base_dir="$1"
  local tz="$2"
  local use_domain="$3"
  local domain="$4"
  local admin_email="$5"
  local siteurl="$6"
  local pg_user="$7"
  local pg_pass="$8"
  local pg_db="$9"
  local mm_tag="${10}"
  local public_port="${11}"

  mkdir -p "$base_dir"
  cd "$base_dir"

  cat > .env <<EOF
TZ=${tz}
POSTGRES_USER=${pg_user}
POSTGRES_PASSWORD=${pg_pass}
POSTGRES_DB=${pg_db}
MM_SITEURL=${siteurl}
MATTERMOST_IMAGE_TAG=${mm_tag}
DOMAIN=${domain}
ADMIN_EMAIL=${admin_email}
EOF

  cat > Caddyfile <<'EOF'
{
	email {$ADMIN_EMAIL}
}

{$DOMAIN} {
	encode gzip
	reverse_proxy mattermost:8065
}
EOF

  cat > docker-compose.yml <<EOF
services:
  postgres:
    image: postgres:16-alpine
    container_name: mm-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: \${POSTGRES_USER}
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      POSTGRES_DB: \${POSTGRES_DB}
    volumes:
      - db_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${POSTGRES_USER} -d \${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 10

  mattermost:
    image: mattermost/mattermost-enterprise-edition:\${MATTERMOST_IMAGE_TAG}
    container_name: mm-app
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      MM_SQLSETTINGS_DRIVERNAME: postgres
      MM_SQLSETTINGS_DATASOURCE: postgres://\${POSTGRES_USER}:\${POSTGRES_PASSWORD}@postgres:5432/\${POSTGRES_DB}?sslmode=disable&connect_timeout=10
      MM_SERVICESETTINGS_SITEURL: \${MM_SITEURL}
      MM_LOGSETTINGS_CONSOLELEVEL: INFO
      TZ: \${TZ}
    ports:
      - "${public_port}:8065"
    volumes:
      - mm_config:/mattermost/config
      - mm_data:/mattermost/data
      - mm_logs:/mattermost/logs
      - mm_plugins:/mattermost/plugins
      - mm_client_plugins:/mattermost/client/plugins
      - mm_bleve:/mattermost/bleve-indexes
EOF

  if [[ "$use_domain" == "yes" ]]; then
    cat >> docker-compose.yml <<'EOF'

    caddy:
    image: caddy:2-alpine
    container_name: mm-caddy
    restart: unless-stopped
    depends_on:
      - mattermost
    ports:
      - "80:80"
      - "443:443"
    environment:
      - TZ=${TZ}
      - DOMAIN=${DOMAIN}
      - ADMIN_EMAIL=${ADMIN_EMAIL}
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config

EOF
  fi

  cat >> docker-compose.yml <<'EOF'

volumes:
  db_data:
  mm_config:
  mm_data:
  mm_logs:
  mm_plugins:
  mm_client_plugins:
  mm_bleve:
EOF

  if [[ "$use_domain" == "yes" ]]; then
    cat >> docker-compose.yml <<'EOF'
  caddy_data:
  caddy_config:
EOF
  fi
}

main() {
  need_root
  bold "Mattermost on a bare server — interactive installer"
  echo

  info "Detected OS: $(detect_os)"

  ensure_basics
  ensure_docker

  local COMPOSE; COMPOSE="$(compose_cmd)"
  info "Compose command: $COMPOSE"
  echo

  local base_dir tz use_domain domain admin_email siteurl public_port
  base_dir="$(read_default "Install directory" "/opt/mattermost")"
  tz="$(read_default "Timezone (TZ)" "Asia/Tehran")"

  echo
  bold "URL / Access"
  use_domain="no"
  if yesno "Use a domain + automatic HTTPS (Caddy + Let's Encrypt)?" "y"; then
    use_domain="yes"
  fi

  if [[ "$use_domain" == "yes" ]]; then
    domain="$(read_default "Domain (e.g. chat.example.com)" "chat.example.com")"
    admin_email="$(read_default "Email for TLS certificates" "admin@example.com")"
    siteurl="https://${domain}"
    public_port="8065"
  else
    domain="$(read_default "Public IP/host (just for reference)" "YOUR_SERVER_IP")"
    admin_email="admin@example.com"
    local host
    host="$(read_default "Mattermost host (IP or hostname users will open)" "YOUR_SERVER_IP")"
    public_port="$(read_default "Public port to expose Mattermost on" "8065")"
    siteurl="http://${host}:${public_port}"
  fi

  echo
  bold "Database"
  local pg_user pg_db pg_pass
  pg_user="$(read_default "Postgres user" "mmuser")"
  pg_db="$(read_default "Postgres db name" "mattermost")"
  if yesno "Auto-generate a strong Postgres password?" "y"; then
    pg_pass="$(gen_pw)"
    info "Generated Postgres password: $pg_pass"
    warn "Save it somewhere safe."
  else
    pg_pass="$(read_secret "Postgres password")"
  fi

  echo
  bold "Mattermost"
  local mm_tag
  mm_tag="$(read_default "Mattermost image tag" "10.5.2")"

  echo
  bold "Firewall"
  ensure_firewall_ports "$use_domain"

  echo
  bold "Writing files"
  write_files "$base_dir" "$tz" "$use_domain" "$domain" "$admin_email" "$siteurl" "$pg_user" "$pg_pass" "$pg_db" "$mm_tag" "$public_port"
  info "Files written under: $base_dir"

  echo
  bold "Starting stack"
  cd "$base_dir"
  $COMPOSE up -d

  echo
  bold "Status"
  $COMPOSE ps

  echo
  bold "Access"
  if [[ "$use_domain" == "yes" ]]; then
    info "Open: https://${domain}"
    warn "Ensure DNS A record points to this server + ports 80/443 open."
  else
    info "Open: ${siteurl}"
  fi

  echo
  info "Logs:"
  info "  App: $COMPOSE logs -f mattermost"
  info "  DB : $COMPOSE logs -f postgres"
  if [[ "$use_domain" == "yes" ]]; then
    info "  TLS: $COMPOSE logs -f caddy"
  fi
}

main "$@"
