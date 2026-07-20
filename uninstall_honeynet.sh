#!/usr/bin/env bash
set -Eeuo pipefail

readonly SERVICE_NAME="honeynet.service"
readonly BASE_DIR="/opt/honeynet"
readonly PROJECT_DIR="${BASE_DIR}/honeynet"
readonly ENV_FILE="/etc/default/honeynet"

log()  { printf '[*] %s\n' "$*"; }
ok()   { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Usage: sudo ./uninstall_honeynet.sh [--remove-images] [--prune]

Options:
  --remove-images  Remove images built by this honeynet project.
  --prune          Run a host-wide Docker prune, including unused volumes.
                   Use only on a dedicated laboratory host.
  -h, --help       Show this help text.
USAGE
}

[[ ${EUID} -eq 0 ]] || fail "Run this script with sudo: sudo ./uninstall_honeynet.sh"

remove_images=0
prune=0
while (( $# )); do
  case "$1" in
    --remove-images) remove_images=1 ;;
    --prune) prune=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; fail "Unknown option: $1" ;;
  esac
  shift
done

log "Stopping and disabling ${SERVICE_NAME}..."
systemctl stop "$SERVICE_NAME" 2>/dev/null || true
systemctl disable "$SERVICE_NAME" 2>/dev/null || true

if [[ -f "${PROJECT_DIR}/compose.yml" ]] && command -v docker >/dev/null 2>&1; then
  log "Stopping containers and removing project networks and volumes..."
  if (( remove_images )); then
    (cd "$PROJECT_DIR" && docker compose down -v --remove-orphans --rmi local) || true
  else
    (cd "$PROJECT_DIR" && docker compose down -v --remove-orphans) || true
  fi
fi

log "Removing systemd unit and environment file..."
rm -f "/etc/systemd/system/${SERVICE_NAME}" "$ENV_FILE"
systemctl daemon-reload
systemctl reset-failed "$SERVICE_NAME" 2>/dev/null || true

log "Removing ${BASE_DIR}..."
rm -rf "$BASE_DIR"

if command -v docker >/dev/null 2>&1; then
  docker network rm honeynet_default honeynet_normalidad honeynet_pentesting >/dev/null 2>&1 || true
  docker volume rm honeynet_db_data1 honeynet_db_data2 honeynet_portainer_data >/dev/null 2>&1 || true
fi

if (( prune )) && command -v docker >/dev/null 2>&1; then
  warn "Running host-wide Docker cleanup. This may remove resources belonging to other projects."
  docker system prune -af --volumes
else
  printf '[INFO] Host-wide Docker cleanup was not performed.\n'
fi

ok "Honeynet uninstalled. Docker Engine and unrelated Docker resources were preserved."
