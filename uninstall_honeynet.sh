#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Reejecutando con sudo..."
  exec sudo bash "$0" "$@"
fi

SERVICE="honeynet.service"
WORKDIR="/opt/honeynet/honeynet"
BASEDIR="/opt/honeynet"

echo "[1] Parando servicio..."
systemctl stop $SERVICE || true
systemctl disable $SERVICE || true

echo "[2] Bajando stack docker..."
if [ -d "$WORKDIR" ]; then
  cd "$WORKDIR"
  docker compose down -v --remove-orphans || true
fi

echo "[3] Eliminando servicio..."
rm -f /etc/systemd/system/$SERVICE
systemctl daemon-reload

echo "[4] Eliminando directorio..."
rm -rf "$BASEDIR"

echo "[5] Limpiando docker..."
docker system prune -af --volumes

echo "✔ Desinstalación completada."