#!/usr/bin/env bash
set -Eeuo pipefail

readonly BASE_DIR="/opt/honeynet"
readonly PROJECT_DIR="${BASE_DIR}/honeynet"
readonly SERVICE_NAME="honeynet.service"
readonly ENV_FILE="/etc/default/honeynet"
readonly MIN_RAM_MIB=6144
readonly MIN_DISK_MIB=12288
readonly STARTUP_TIMEOUT=240

log()  { printf '[*] %s\n' "$*"; }
ok()   { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

on_error() {
  local exit_code=$?
  printf '[ERROR] Installation failed at line %s (exit code %s).\n' "$1" "$exit_code" >&2
  exit "$exit_code"
}
trap 'on_error "$LINENO"' ERR

require_root() {
  [[ ${EUID} -eq 0 ]] || fail "Run this installer with sudo: sudo ./install_honeynet.sh"
}

script_dir() {
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

check_resources() {
  local ram_mib disk_mib cpus
  ram_mib=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
  disk_mib=$(df -Pm /opt 2>/dev/null | awk 'NR==2 {print $4}')
  [[ -n "$disk_mib" ]] || disk_mib=$(df -Pm / | awk 'NR==2 {print $4}')
  cpus=$(nproc)

  (( cpus >= 2 )) || warn "Only ${cpus} CPU detected; 4 vCPUs are recommended."
  (( ram_mib >= MIN_RAM_MIB )) || fail "Insufficient RAM: ${ram_mib} MiB available; at least ${MIN_RAM_MIB} MiB is required (8 GiB recommended)."
  (( disk_mib >= MIN_DISK_MIB )) || fail "Insufficient free disk space: ${disk_mib} MiB; at least ${MIN_DISK_MIB} MiB is required."
  ok "Resource check passed (${cpus} CPU, ${ram_mib} MiB RAM, ${disk_mib} MiB free disk)."
}

detect_os() {
  [[ -r /etc/os-release ]] || fail "/etc/os-release was not found."
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-unknown}"
  OS_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
}

check_network() {
  if command_exists curl && curl -fsSIL --connect-timeout 8 https://download.docker.com/ >/dev/null 2>&1; then
    return
  fi
  if command_exists getent && getent hosts download.docker.com >/dev/null 2>&1; then
    return
  fi
  fail "Internet connectivity or DNS resolution is unavailable."
}

install_docker_apt() {
  log "Installing Docker Engine and Docker Compose plugin (APT)..."
  apt-get update
  apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings

  local docker_distro="$OS_ID"
  [[ "$docker_distro" == "linuxmint" ]] && docker_distro="ubuntu"
  [[ -n "$OS_CODENAME" ]] || fail "Unable to determine the distribution codename."

  curl -fsSL "https://download.docker.com/linux/${docker_distro}/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/%s %s stable\n' \
    "$(dpkg --print-architecture)" "$docker_distro" "$OS_CODENAME" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_docker_dnf() {
  log "Installing Docker Engine and Docker Compose plugin (DNF)..."
  dnf -y install dnf-plugins-core
  dnf config-manager --add-repo "https://download.docker.com/linux/${OS_ID}/docker-ce.repo" || true
  dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    || dnf -y install docker docker-compose
}

install_docker_zypper() {
  log "Installing Docker and Docker Compose (Zypper)..."
  zypper --non-interactive refresh
  zypper --non-interactive install docker docker-compose-plugin \
    || zypper --non-interactive install docker docker-compose
}

install_docker_pacman() {
  log "Installing Docker and Docker Compose (Pacman)..."
  pacman -Sy --noconfirm docker docker-compose
}

ensure_docker() {
  if command_exists docker && docker compose version >/dev/null 2>&1; then
    log "Docker and Docker Compose are already available."
  else
    check_network
    detect_os
    case "$OS_ID" in
      ubuntu|debian|linuxmint) install_docker_apt ;;
      fedora|rhel|centos|rocky|almalinux) install_docker_dnf ;;
      opensuse*|sles) install_docker_zypper ;;
      arch|manjaro) install_docker_pacman ;;
      *) fail "Unsupported distribution (${OS_ID}). Install Docker Engine and the Compose plugin manually, then rerun this installer." ;;
    esac
  fi

  systemctl enable --now docker
  docker info >/dev/null 2>&1 || fail "The Docker daemon is not available."
  docker compose version >/dev/null 2>&1 || fail "The Docker Compose plugin is not available."
}

select_host_ip() {
  local ip_addr
  ip_addr=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')
  [[ -n "$ip_addr" ]] || ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}')
  [[ -n "$ip_addr" ]] || fail "Unable to determine HOST_IP automatically."
  printf '%s' "$ip_addr"
}

verify_distribution() {
  local src archive checksum_file
  src=$(script_dir)
  archive="${src}/honeynet.tar.gz"
  checksum_file="${src}/SHA256SUMS"

  [[ -s "$archive" ]] || fail "Missing or empty archive: ${archive}"
  tar -tzf "$archive" >/dev/null || fail "The archive ${archive} is corrupt or not a valid gzip-compressed tar file."

  if [[ -f "$checksum_file" ]]; then
    log "Verifying distribution checksums..."
    (cd "$src" && sha256sum --ignore-missing -c SHA256SUMS) || fail "Checksum verification failed."
  else
    warn "SHA256SUMS was not found; package integrity cannot be verified."
  fi
}

create_log_directories() {
  local log_dirs=(
    ftp_normalidad ftp_pentesting
    ssh_normalidad ssh_pentesting
    mailserver_normalidad mailserver_pentesting
    dvwa_normalidad dvwa_pentesting
    database_normalidad database_pentesting
    restful_api_normalidad restful_api_pentesting
    smb_normalidad smb_pentesting
    vpn_normalidad vpn_pentesting
  )
  local log_dir

  log "Creating log and Fluentd buffer directories..."
  mkdir -p "${PROJECT_DIR}/logs"
  for log_dir in "${log_dirs[@]}"; do
    mkdir -p "${PROJECT_DIR}/logs/${log_dir}"
    [[ "$log_dir" == dvwa_* ]] || mkdir -p "${PROJECT_DIR}/logs/${log_dir}/buffer"
  done
  find "${PROJECT_DIR}/logs" -type d -exec chmod 0775 {} +

  # mitmproxy runs as UID/GID 1000 in the pinned image. Pre-create the
  # two HTTP JSON log files with matching ownership so clean deployments
  # can append telemetry immediately without weakening unrelated paths.
  touch \
    "${PROJECT_DIR}/logs/dvwa_normalidad/dvwa_normalidad.log" \
    "${PROJECT_DIR}/logs/dvwa_pentesting/dvwa_pentesting.log"
  chown 1000:1000 \
    "${PROJECT_DIR}/logs/dvwa_normalidad" \
    "${PROJECT_DIR}/logs/dvwa_pentesting" \
    "${PROJECT_DIR}/logs/dvwa_normalidad/dvwa_normalidad.log" \
    "${PROJECT_DIR}/logs/dvwa_pentesting/dvwa_pentesting.log"
  chmod 0775 \
    "${PROJECT_DIR}/logs/dvwa_normalidad" \
    "${PROJECT_DIR}/logs/dvwa_pentesting"
  chmod 0664 \
    "${PROJECT_DIR}/logs/dvwa_normalidad/dvwa_normalidad.log" \
    "${PROJECT_DIR}/logs/dvwa_pentesting/dvwa_pentesting.log"

  chown -R 1000:1000 "${PROJECT_DIR}/mitmproxy" 2>/dev/null || true
}

create_runtime_directories() {
  local runtime_dirs=(
    mailserver1/data mailserver1/state
    mailserver2/data mailserver2/state
    vpn/wireguard_normalidad vpn/wireguard_pentesting
    mitmproxy/config/normalidad mitmproxy/config/pentesting
  )
  local runtime_dir

  log "Creating clean runtime-state directories..."
  for runtime_dir in "${runtime_dirs[@]}"; do
    mkdir -p "${PROJECT_DIR}/${runtime_dir}"
  done
  chmod 0755 \
    "${PROJECT_DIR}/mailserver1/data" "${PROJECT_DIR}/mailserver1/state" \
    "${PROJECT_DIR}/mailserver2/data" "${PROJECT_DIR}/mailserver2/state"
  chmod 0700 \
    "${PROJECT_DIR}/vpn/wireguard_normalidad" \
    "${PROJECT_DIR}/vpn/wireguard_pentesting"
  chown -R 1000:1000 "${PROJECT_DIR}/mitmproxy/config/normalidad" "${PROJECT_DIR}/mitmproxy/config/pentesting" 2>/dev/null || true
}

install_project_files() {
  local src archive host_ip
  src=$(script_dir)
  archive="${src}/honeynet.tar.gz"

  log "Stopping any previous honeynet deployment..."
  systemctl stop "$SERVICE_NAME" 2>/dev/null || true

  if [[ -r "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    set -a; . "$ENV_FILE"; set +a
  fi
  if [[ -f "${PROJECT_DIR}/compose.yml" ]]; then
    (cd "$PROJECT_DIR" && docker compose down --remove-orphans) || true
  fi

  log "Installing project files in ${BASE_DIR}..."
  rm -rf "$BASE_DIR"
  mkdir -p "$BASE_DIR"
  tar -xzf "$archive" -C "$BASE_DIR"
  [[ -f "${PROJECT_DIR}/compose.yml" ]] || fail "The archive does not contain honeynet/compose.yml."

  create_log_directories
  create_runtime_directories

  host_ip=$(select_host_ip)
  install -d -m 0755 "$(dirname "$ENV_FILE")"
  printf 'HOST_IP=%s\n' "$host_ip" > "$ENV_FILE"
  chmod 0644 "$ENV_FILE"
  export HOST_IP="$host_ip"
  ok "HOST_IP=${HOST_IP}"
}

validate_compose() {
  local required_services configured service
  required_services=(
    fluentd portainer
    ssh_normalidad ssh_pentesting
    ftp_normalidad ftp_pentesting
    dvwa_normalidad dvwa_pentesting
    reverse_proxy_normalidad reverse_proxy_pentesting
    mailserver_normalidad mailserver_pentesting
    db_normalidad db_pentesting
    api_normalidad api_pentesting
    smb_normalidad smb_pentesting
    wireguard_normalidad wireguard_pentesting
    wg_collector_normalidad wg_collector_pentesting
  )

  log "Validating Docker Compose configuration..."
  (cd "$PROJECT_DIR" && docker compose config --quiet)
  configured=$(cd "$PROJECT_DIR" && docker compose config --services)
  for service in "${required_services[@]}"; do
    grep -qx "$service" <<< "$configured" || fail "Missing required Compose service: ${service}"
  done
  ok "Compose configuration is valid."
}

start_stack() {
  log "Building local images..."
  (cd "$PROJECT_DIR" && docker compose build --pull)

  log "Starting the honeynet..."
  (cd "$PROJECT_DIR" && docker compose up -d --remove-orphans)
}

verify_running_services() {
  local long_running service cid state deadline all_running
  long_running=(
    fluentd portainer
    ssh_normalidad ssh_pentesting
    ftp_normalidad ftp_pentesting
    dvwa_normalidad dvwa_pentesting
    reverse_proxy_normalidad reverse_proxy_pentesting
    mailserver_normalidad mailserver_pentesting
    db_normalidad db_pentesting
    api_normalidad api_pentesting
    smb_normalidad smb_pentesting
    wireguard_normalidad wireguard_pentesting
    wg_collector_normalidad wg_collector_pentesting
  )

  log "Waiting for long-running services..."
  deadline=$((SECONDS + STARTUP_TIMEOUT))
  while (( SECONDS < deadline )); do
    all_running=1
    for service in "${long_running[@]}"; do
      cid=$(cd "$PROJECT_DIR" && docker compose ps -q "$service")
      [[ -n "$cid" ]] || { all_running=0; continue; }
      state=$(docker inspect -f '{{.State.Status}}' "$cid" 2>/dev/null || true)
      [[ "$state" == "running" ]] || all_running=0
    done
    (( all_running == 1 )) && break
    sleep 4
  done

  local failed=()
  for service in "${long_running[@]}"; do
    cid=$(cd "$PROJECT_DIR" && docker compose ps -q "$service")
    [[ -n "$cid" ]] || { failed+=("${service}:not-created"); continue; }
    state=$(docker inspect -f '{{.State.Status}}' "$cid" 2>/dev/null || true)
    [[ "$state" == "running" ]] || failed+=("${service}:${state:-unknown}")
  done

  if (( ${#failed[@]} )); then
    printf '[ERROR] Services not running:\n' >&2
    printf '  - %s\n' "${failed[@]}" >&2
    (cd "$PROJECT_DIR" && docker compose ps -a && docker compose logs --no-color --tail=120) >&2 || true
    fail "Incomplete deployment."
  fi
  ok "All ${#long_running[@]} long-running services are running."
}

install_systemd_unit() {
  local src service_unit
  src=$(script_dir)
  service_unit="${src}/${SERVICE_NAME}"
  [[ -f "$service_unit" ]] || fail "Missing ${service_unit}."

  log "Installing systemd unit..."
  systemctl stop "$SERVICE_NAME" 2>/dev/null || true
  systemctl disable "$SERVICE_NAME" 2>/dev/null || true
  rm -rf "/etc/systemd/system/${SERVICE_NAME}"
  install -m 0644 "$service_unit" "/etc/systemd/system/${SERVICE_NAME}"
  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME"
  systemctl restart "$SERVICE_NAME"
}

show_status() {
  printf '\n'
  (cd "$PROJECT_DIR" && docker compose ps)
  printf '\n'
  ok "Honeynet installation completed successfully."
  printf 'Project directory: %s\n' "$PROJECT_DIR"
  printf 'Environment file:  %s\n' "$ENV_FILE"
  printf 'Service status:    systemctl status %s\n' "$SERVICE_NAME"
  printf 'Container status:  cd %s && sudo docker compose ps\n' "$PROJECT_DIR"
}

main() {
  require_root
  check_resources
  verify_distribution
  ensure_docker
  install_project_files
  validate_compose
  start_stack
  verify_running_services
  install_systemd_unit
  show_status
}

main "$@"
