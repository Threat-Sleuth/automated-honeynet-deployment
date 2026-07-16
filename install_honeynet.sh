#!/usr/bin/env bash
set -Eeuo pipefail

readonly BASE_DIR="/opt/honeynet"
readonly PROJECT_DIR="${BASE_DIR}/honeynet"
readonly SERVICE_NAME="honeynet.service"
readonly ENV_FILE="/etc/default/honeynet"

log() { printf '[*] %s\n' "$*"; }
ok() { printf '[OK] %s\n' "$*"; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

trap 'printf "[ERROR] Installation failed at line %s.\n" "$LINENO" >&2' ERR

require_root() {
  [[ ${EUID} -eq 0 ]] || fail "Run this installer with sudo: sudo ./install_honeynet.sh"
}

script_dir() {
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

detect_os() {
  [[ -r /etc/os-release ]] || fail "/etc/os-release was not found."
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-unknown}"
  OS_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
}

install_docker_apt() {
  log "Installing Docker Engine and Docker Compose plugin (APT)..."
  apt-get update
  apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings

  local docker_distro="$OS_ID"
  [[ "$docker_distro" == "linuxmint" ]] && docker_distro="ubuntu"

  curl -fsSL "https://download.docker.com/linux/${docker_distro}/gpg" \
    -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  [[ -n "$OS_CODENAME" ]] || fail "Unable to determine the distribution codename."
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
    detect_os
    case "$OS_ID" in
      ubuntu|debian|linuxmint) install_docker_apt ;;
      fedora|rhel|centos|rocky|almalinux) install_docker_dnf ;;
      opensuse*|sles) install_docker_zypper ;;
      arch|manjaro) install_docker_pacman ;;
      *) fail "Unsupported distribution (${OS_ID}). Install Docker and the Compose plugin manually, then rerun this installer." ;;
    esac
  fi

  systemctl enable --now docker
  docker compose version >/dev/null 2>&1 || fail "The Docker Compose plugin is not available."
}

select_host_ip() {
  local ip
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  if [[ -z "$ip" ]]; then
    ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')"
  fi
  [[ -n "$ip" ]] || fail "Unable to determine HOST_IP automatically."
  printf '%s' "$ip"
}

prepare_project() {
  local src archive service host_ip
  src="$(script_dir)"
  archive="${src}/honeynet.tar.gz"
  service="${src}/${SERVICE_NAME}"

  [[ -f "$archive" ]] || fail "Missing ${archive}."
  [[ -f "$service" ]] || fail "Missing ${service}."

  log "Stopping any previous honeynet deployment..."
  systemctl stop "$SERVICE_NAME" 2>/dev/null || true
  if [[ -f "${PROJECT_DIR}/compose.yml" ]]; then
    (cd "$PROJECT_DIR" && docker compose down --remove-orphans) || true
  fi

  log "Installing project files in ${BASE_DIR}..."
  rm -rf "$BASE_DIR"
  mkdir -p "$BASE_DIR"
  tar -xzf "$archive" -C "$BASE_DIR"
  [[ -f "${PROJECT_DIR}/compose.yml" ]] || fail "The archive does not contain honeynet/compose.yml."

  find "${PROJECT_DIR}/logs" -type d -exec chmod 0777 {} + 2>/dev/null || true
  chown -R 1000:1000 "${PROJECT_DIR}/mitmproxy" 2>/dev/null || true

  host_ip="$(select_host_ip)"
  install -d -m 0755 "$(dirname "$ENV_FILE")"
  printf 'HOST_IP=%s\n' "$host_ip" > "$ENV_FILE"
  chmod 0644 "$ENV_FILE"
  export HOST_IP="$host_ip"
  log "HOST_IP=${HOST_IP}"

  log "Validating Docker Compose configuration..."
  (cd "$PROJECT_DIR" && docker compose config --quiet)

  log "Building and starting the honeynet..."
  (cd "$PROJECT_DIR" && docker compose up -d --build)

  log "Installing the systemd service..."
  install -m 0644 "$service" "/etc/systemd/system/${SERVICE_NAME}"
  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME"
  systemctl restart "$SERVICE_NAME"
}

show_status() {
  printf '\n'
  docker compose -f "${PROJECT_DIR}/compose.yml" ps
  printf '\n'
  ok "Installation completed."
  printf 'Project directory: %s\n' "$PROJECT_DIR"
  printf 'Service status:   systemctl status %s\n' "$SERVICE_NAME"
  printf 'Container status: cd %s && sudo docker compose ps\n' "$PROJECT_DIR"
}

main() {
  require_root
  ensure_docker
  prepare_project
  show_status
}

main "$@"
