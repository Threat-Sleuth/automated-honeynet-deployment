# Extended Container-Based Honeynet Auto-Deployment

This release deploys a reproducible, Docker-based honeynet composed of **eight service families**, each duplicated into two isolated experimental environments:

- **normalidad** for legitimate or benign traffic;
- **pentesting** for controlled attack and anomalous traffic.

The deployment preserves the experimental separation used by the original four-service honeynet and extends it with PostgreSQL, a REST API implemented with FastAPI, SMB, and WireGuard VPN.

## Architecture

The stack contains paired instances of:

1. HTTP/DVWA
2. FTP
3. SSH
4. SMTP/IMAP mail server
5. PostgreSQL database
6. FastAPI REST service
7. SMB file sharing
8. WireGuard VPN

Supporting components include:

- **Fluentd**, for centralized JSON-oriented logging;
- **mitmproxy**, acting as a reverse proxy and application-level logger for DVWA;
- **Portainer**, bound to localhost for optional Docker administration.

The PostgreSQL service can be accessed directly or indirectly through FastAPI. This allows experiments against both the database protocol and a modern HTTP/JSON application layer using OAuth2/JWT-style authentication and CRUD operations.

## Release contents

Place these files together before installation:

```text
install_honeynet.sh
uninstall_honeynet.sh
honeynet.service
honeynet.tar.gz
README.md
SERVICE_PORTS.txt
SHA256SUMS
```

`honeynet.tar.gz` contains the Docker Compose project and all service files.

## Tested platform

The original deployment line has been validated primarily on Ubuntu 24.04 LTS. The installer also provides best-effort support for modern systemd-based distributions using:

- APT: Ubuntu, Debian, Linux Mint
- DNF: Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux
- Zypper: openSUSE, SLES
- Pacman: Arch Linux, Manjaro

Docker Compose v2 (`docker compose`) is required.

## Installation

### 1. Download the release files

Keep all release assets in the same directory.

### 2. Optionally verify integrity

```bash
sha256sum -c SHA256SUMS
```

### 3. Make the scripts executable

```bash
chmod +x install_honeynet.sh uninstall_honeynet.sh
```

### 4. Run the installer

```bash
sudo ./install_honeynet.sh
```

The installer:

1. verifies root privileges;
2. installs Docker and Docker Compose when necessary;
3. deploys the project under `/opt/honeynet/honeynet`;
4. determines the first reachable host IPv4 address;
5. stores it as `HOST_IP` in `/etc/default/honeynet` for WireGuard and systemd restarts;
6. validates the Compose configuration;
7. builds and starts the containers;
8. installs and enables `honeynet.service`.

## Published ports

| Service | Normalidad | Pentesting |
|---|---:|---:|
| DVWA through mitmproxy | `80/tcp` | `81/tcp` |
| FTP control | `2121/tcp` | `2122/tcp` |
| FTP passive range | `21100-21110/tcp` | `21111-21121/tcp` |
| SSH | `2222/tcp` | `2223/tcp` |
| SMTP | `25/tcp` | `2525/tcp` |
| Submission | `587/tcp` | `1587/tcp` |
| IMAP | `143/tcp` | `1143/tcp` |
| IMAPS | `993/tcp` | `1993/tcp` |
| PostgreSQL | `5433/tcp` | `5434/tcp` |
| FastAPI | `8000/tcp` | `8001/tcp` |
| SMB | `445/tcp` | `1445/tcp` |
| WireGuard tunnel | `51820/udp` | `51822/udp` |
| WireGuard web interface | `51821/tcp` | `51823/tcp` |

Infrastructure ports:

- Fluentd: `24224/tcp` and `24224/udp`
- Portainer: `127.0.0.1:9000/tcp`

## Default laboratory credentials

These credentials are intentionally simple and are intended only for an isolated laboratory:

| Service | Username | Password / database |
|---|---|---|
| DVWA | `admin` | `password` |
| FTP | `ftpuser` | `password` |
| SSH | `root` | `password` |
| Mail | `usuario1` / `usuario2` | `password` |
| SMB | `user` | `password` |
| PostgreSQL | `myuser` | `mypassword` |
| PostgreSQL database | — | `mydatabase` |

Mail domains:

- `normalidad.tics`
- `pentesting.tics`

The API credentials and cryptographic secret are supplied to the containers through Docker secrets stored inside the packaged project.

> **Warning:** Do not expose this stack directly to the public Internet. Change credentials and apply network controls if the environment is reachable by untrusted systems.

## Verifying the deployment

```bash
sudo docker ps
sudo systemctl status honeynet.service
cd /opt/honeynet/honeynet
sudo docker compose ps
```

Useful endpoint checks include:

```bash
curl -I http://HOST_IP:80
curl -I http://HOST_IP:81
curl http://HOST_IP:8000/docs
curl http://HOST_IP:8001/docs
```

Portainer is available locally at:

```text
http://localhost:9000
```

## Service management

```bash
sudo systemctl start honeynet.service
sudo systemctl stop honeynet.service
sudo systemctl restart honeynet.service
sudo systemctl status honeynet.service
```

Direct Docker Compose management:

```bash
cd /opt/honeynet/honeynet
sudo docker compose up -d
sudo docker compose stop
sudo docker compose down
sudo docker compose logs -f
```

## Changing the host IP used by WireGuard

The installer writes:

```text
/etc/default/honeynet
```

with content similar to:

```bash
HOST_IP=192.0.2.10
```

After changing the host address, update this file and recreate the VPN containers:

```bash
sudo nano /etc/default/honeynet
sudo systemctl restart honeynet.service
```

## Logging

Fluentd receives logs using service- and environment-specific tags, including:

```text
normalidad.ssh             pentesting.ssh
normalidad.ftp             pentesting.ftp
normalidad.mailserver      pentesting.mailserver
normalidad.db              pentesting.db
normalidad.api             pentesting.api
normalidad.smb             pentesting.smb
normalidad.vpn             pentesting.vpn
```

DVWA traffic is logged separately by the two mitmproxy reverse proxies.

Logs are stored under:

```text
/opt/honeynet/honeynet/logs/
```

with separate directories for normal and pentesting activity.

## Uninstallation

Standard removal:

```bash
sudo ./uninstall_honeynet.sh
```

This removes the containers, project volumes, systemd unit, environment file, and `/opt/honeynet`. Docker remains installed, and unrelated Docker resources are preserved.

To additionally prune **all unused Docker images, networks, volumes, and build cache on the host**:

```bash
sudo ./uninstall_honeynet.sh --prune
```

Use `--prune` carefully on hosts running other Docker projects.

## Customization

The Compose project can be extended by modifying `/opt/honeynet/honeynet/compose.yml` and the corresponding service directories. After changes:

```bash
cd /opt/honeynet/honeynet
sudo docker compose config
sudo docker compose up -d --build
```

Keep the normalidad/pentesting separation and logging tags consistent if the environment is used for controlled dataset generation.

## Security and research disclaimer

This software intentionally deploys vulnerable or weakly protected services for controlled cybersecurity experimentation. Run it only in an isolated environment and comply with applicable laws, institutional policies, and ethical requirements. The maintainers accept no responsibility for misuse or deployment on untrusted networks.

## Log-directory robustness (v2.0.1)

The installer explicitly creates all log and Fluentd buffer directories before starting the stack. The packaged project also contains `.gitkeep` files so the complete directory tree is preserved when the repository is cloned or downloaded from GitHub.
