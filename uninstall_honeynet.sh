#!/usr/bin/env bash
set -Eeuo pipefail

readonly SERVICE_NAME="honeynet.service"
readonly BASE_DIR="/opt/honeynet"
readonly PROJECT_DIR="${BASE_DIR}/honeynet"
readonly ENV_FILE="/etc/default/honeynet"

log() { printf '[*] %s\n' "$*"; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

[[ ${EUID} -eq 0 ]] || fail "Run this script with sudo: sudo ./uninstall_honeynet.sh"

log "Stopping and disabling ${SERVICE_NAME}..."
systemctl stop "$SERVICE_NAME" 2>/dev/null || true
systemctl disable "$SERVICE_NAME" 2>/dev/null || true

if [[ -f "${PROJECT_DIR}/compose.yml" ]] && command -v docker >/dev/null 2>&1; then
  log "Stopping containers and removing project volumes..."
  (cd "$PROJECT_DIR" && docker compose down -v --remove-orphans) || true
fi

log "Removing systemd unit and environment file..."
rm -f "/etc/systemd/system/${SERVICE_NAME}" "$ENV_FILE"
systemctl daemon-reload
systemctl reset-failed "$SERVICE_NAME" 2>/dev/null || true

log "Removing ${BASE_DIR}..."
rm -rf "$BASE_DIR"

if [[ "${1:-}" == "--prune" ]] && command -v docker >/dev/null 2>&1; then
  log "Pruning unused Docker data..."
  docker system prune -af --volumes
else
  printf '[INFO] Docker-wide cleanup was not performed. Use --prune to remove all unused Docker data.\n'
fi

printf '[OK] Honeynet uninstalled. Docker itself was left installed.\n'
