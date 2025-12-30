#!/usr/bin/env bash
set -e

# Universal (best-effort) installer for Docker-based honeynet
# Primarily tested on Ubuntu 24.04 LTS.

# 1. Check that the script is running as root
if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] Please run this script with sudo (sudo ./install_honeynet.sh)."
  exit 1
fi

# 2. Detect package manager based on the Linux distribution
PKG_MANAGER=""

detect_pkg_manager() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
      ubuntu|debian)
        PKG_MANAGER="apt"
        ;;
      fedora)
        PKG_MANAGER="dnf"
        ;;
      centos|rhel|rocky|almalinux)
        PKG_MANAGER="dnf"
        ;;
      opensuse*|sles)
        PKG_MANAGER="zypper"
        ;;
      arch)
        PKG_MANAGER="pacman"
        ;;
      *)
        echo "[ERROR] Distribution not automatically supported (ID=$ID). Please install Docker manually and re-run this script."
        exit 1
        ;;
    esac
  else
    echo "[ERROR] /etc/os-release not found. Unable to detect Linux distribution."
    exit 1
  fi
}

# 3. Install Docker and Docker Compose plugin using the detected package manager
install_docker() {
  echo "[*] Detecting Linux distribution and package manager..."
  detect_pkg_manager
  echo "[*] Detected package manager: $PKG_MANAGER"

  case "$PKG_MANAGER" in
    apt)
      echo "[*] Installing Docker on an APT-based system (Ubuntu/Debian)..."
      apt-get update
      apt-get install -y ca-certificates curl gnupg
      install -m 0755 -d /etc/apt/keyrings
      if [ ! -f /etc/apt/keyrings/docker.asc ]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
      fi
      . /etc/os-release
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        ${UBUNTU_CODENAME:-$VERSION_CODENAME} stable" > /etc/apt/sources.list.d/docker.list
      apt-get update
      apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      ;;
    dnf)
      echo "[*] Installing Docker on a DNF-based system (Fedora/RHEL-like)..."
      dnf -y install dnf-plugins-core
      . /etc/os-release
      dnf config-manager --add-repo https://download.docker.com/linux/$ID/docker-ce.repo
      dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || \
        dnf -y install docker docker-compose
      ;;
    zypper)
      echo "[*] Installing Docker on a Zypper-based system (openSUSE/SLES)..."
      zypper refresh
      zypper install -y docker docker-compose || zypper install -y docker docker-compose-plugin
      ;;
    pacman)
      echo "[*] Installing Docker on a Pacman-based system (Arch)..."
      pacman -Sy --noconfirm docker docker-compose || pacman -Sy --noconfirm docker docker-compose-plugin
      ;;
  esac

  echo "[*] Enabling and starting the Docker service..."
  systemctl enable docker
  systemctl start docker
}

# 4. Common honeynet installation logic
BASE_DIR="/opt/honeynet"
PROJECT_DIR="/opt/honeynet/honeynet"
SERVICE_NAME="honeynet.service"

install_honeynet() {
  echo "[*] Preparing base directory at $BASE_DIR..."
  mkdir -p "$BASE_DIR"

  # It is assumed that honeynet.tar.gz and honeynet.service are in the same directory as this script
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [ ! -f "$SCRIPT_DIR/honeynet.tar.gz" ]; then
    echo "[ERROR] Could not find $SCRIPT_DIR/honeynet.tar.gz. Place the file in the same directory as this script."
    exit 1
  fi

  if [ ! -f "$SCRIPT_DIR/$SERVICE_NAME" ]; then
    echo "[ERROR] Could not find $SCRIPT_DIR/$SERVICE_NAME. Place the file in the same directory as this script."
    exit 1
  fi

  echo "[*] Copying and extracting honeynet.tar.gz into $BASE_DIR..."
  cp "$SCRIPT_DIR/honeynet.tar.gz" "$BASE_DIR/"
  cd "$BASE_DIR"
  tar -xzvf honeynet.tar.gz

  # Special permissions for components
  echo "[*] Adjusting permissions for mitmproxy and logs..."
  if [ -d "$PROJECT_DIR/mitmproxy" ]; then
    chown -R 1000:1000 "$PROJECT_DIR/mitmproxy"
  fi

  if [ -d "$PROJECT_DIR/logs" ]; then
    chmod 777 "$PROJECT_DIR"/logs/dvwa_pentesting "$PROJECT_DIR"/logs/dvwa_normalidad 2>/dev/null || true
  fi

  # Start honeynet for the first time
  echo "[*] Starting the honeynet with docker compose..."
  cd "$PROJECT_DIR"
  docker compose up -d

  # Install systemd service unit
  echo "[*] Installing systemd service $SERVICE_NAME..."
  cp "$SCRIPT_DIR/$SERVICE_NAME" /etc/systemd/system/$SERVICE_NAME

  # Adjust WorkingDirectory in the service unit so it matches PROJECT_DIR
  echo "[*] Adjusting WorkingDirectory in the service unit to match PROJECT_DIR..."
  sed -i "s|^WorkingDirectory=.*|WorkingDirectory=$PROJECT_DIR|" /etc/systemd/system/$SERVICE_NAME

  systemctl daemon-reload
  systemctl enable $SERVICE_NAME
  systemctl start $SERVICE_NAME

  echo "[OK] Installation completed. The honeynet should now be running and will automatically start on system boot."
}

# --- Main workflow ---
install_docker
install_honeynet
