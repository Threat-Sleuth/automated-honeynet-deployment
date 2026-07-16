# Extended Container-Based Honeynet

This repository provides an automated, reproducible Docker deployment of an extended honeynet for controlled cybersecurity experimentation, attack-event capture, and dataset generation.

The platform contains **eight service families**, each duplicated into two experimental environments:

- `normalidad`: legitimate or benign traffic;
- `pentesting`: controlled attacks and anomalous traffic.

The complete stack deploys **20 containers** and has been validated on a clean Ubuntu virtual machine with all containers running simultaneously.

## Architecture

The paired service families are:

1. HTTP/DVWA
2. FTP
3. SSH
4. SMTP/IMAP mail server
5. PostgreSQL database
6. FastAPI REST API
7. SMB file sharing
8. WireGuard VPN

Supporting containers are:

- Fluentd for centralized logging;
- two mitmproxy reverse proxies for DVWA traffic capture;
- Portainer Community Edition for local Docker administration.

The PostgreSQL instances can be accessed directly or through the corresponding FastAPI service, enabling experiments at both the database-protocol and HTTP/JSON application layers.

## Validated deployment

The current release has been validated with:

- all **20 expected containers running**;
- **0 stopped containers**;
- **0 unhealthy containers**;
- SMB and WireGuard health checks passing;
- `honeynet.service` installed, enabled, and started successfully;
- Portainer Community Edition available locally;
- automatic creation of all normal and pentesting log directories.

### Recommended virtual-machine resources

The full stack is significantly heavier than the original four-service deployment. For installation and concurrent execution, use at least:

- **4 virtual CPUs**;
- **8 GB RAM**;
- **30 GB free disk space**.

More memory may be useful while rebuilding all images or running intensive attack-generation campaigns.

## Release files

Keep these files in the same directory:

```text
install_honeynet.sh
uninstall_honeynet.sh
honeynet.service
honeynet.tar.gz
README.md
RELEASE_NOTES.md
SERVICE_PORTS.txt
SHA256SUMS
```

`honeynet.tar.gz` contains the Compose project, service definitions, Dockerfiles, configurations, logging directories, and supporting resources.

## Platform support

The deployment has been validated primarily on **Ubuntu 24.04 LTS**. The installer also provides best-effort support for systemd-based distributions using:

- APT: Ubuntu, Debian, Linux Mint;
- DNF: Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux;
- Zypper: openSUSE, SLES;
- Pacman: Arch Linux, Manjaro.

Docker Compose v2 (`docker compose`) is required.

## Installation

### 1. Verify file integrity

```bash
sha256sum -c SHA256SUMS
```

Every entry should report `OK`.

### 2. Make the scripts executable

```bash
chmod +x install_honeynet.sh uninstall_honeynet.sh
```

### 3. Run the installer

```bash
sudo ./install_honeynet.sh
```

The installer:

1. verifies root privileges;
2. installs Docker Engine and Docker Compose when necessary;
3. stops and removes a previous honeynet deployment;
4. extracts the project under `/opt/honeynet/honeynet`;
5. creates all log and Fluentd buffer directories;
6. determines the host IPv4 address;
7. stores `HOST_IP` in `/etc/default/honeynet`;
8. validates the Compose configuration;
9. checks that all 20 expected services are defined;
10. builds and starts the stack;
11. waits until all 20 expected containers are running;
12. installs and enables `honeynet.service`.

A successful deployment ends with:

```text
[OK] All 20 expected containers are running.
[OK] Installation completed.
```

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

- Fluentd: `24224/tcp` and `24224/udp`;
- Portainer: `127.0.0.1:9000/tcp`.

## Default laboratory credentials

These credentials are intentionally weak and are intended only for an isolated laboratory.

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

API and database secrets are supplied through Docker secrets included in the packaged laboratory project.

> **Warning:** Do not expose this stack directly to the public Internet. Deploy it only in an isolated and controlled environment.

## Verification

```bash
sudo systemctl status honeynet.service
cd /opt/honeynet/honeynet
sudo bash -c 'set -a; source /etc/default/honeynet; set +a; docker compose ps'
```

Useful application checks:

```bash
curl -I http://HOST_IP:80
curl -I http://HOST_IP:81
curl http://HOST_IP:8000/docs
curl http://HOST_IP:8001/docs
```

PostgreSQL port checks:

```bash
nc -zv HOST_IP 5433
nc -zv HOST_IP 5434
```

## Portainer

Portainer Community Edition is pinned to:

```text
portainer/portainer-ce:2.39.5
```

The stack starts it with:

```text
--no-setup-token
```

This preserves browser-based creation of the initial administrator account without requiring the setup-token workflow introduced in recent Portainer releases.

Portainer is bound to localhost:

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

Direct Compose management while loading `HOST_IP`:

```bash
sudo bash -c '
  set -a
  source /etc/default/honeynet
  set +a
  cd /opt/honeynet/honeynet
  docker compose ps
'
```

## Host IP and WireGuard

The installer creates:

```text
/etc/default/honeynet
```

with content similar to:

```bash
HOST_IP=192.0.2.10
```

If the virtual machine address changes, update the file and restart the stack:

```bash
sudo nano /etc/default/honeynet
sudo systemctl restart honeynet.service
```

## Logging

Fluentd receives service- and environment-specific tags:

```text
normalidad.ssh             pentesting.ssh
normalidad.ftp             pentesting.ftp
normalidad.mailserver      pentesting.mailserver
normalidad.db              pentesting.db
normalidad.api             pentesting.api
normalidad.smb             pentesting.smb
normalidad.vpn             pentesting.vpn
```

DVWA traffic is captured separately by the two mitmproxy reverse proxies.

Logs are stored under:

```text
/opt/honeynet/honeynet/logs/
```

The installer explicitly creates the normal and pentesting log directories and Fluentd buffer subdirectories before starting the stack.

## Reproducibility fixes included

This validated package includes the following deployment fixes:

- eight duplicated service families and 20 expected containers;
- valid Docker Fluentd option `fluentd-async`;
- removal of incompatible `/etc/timezone` and `/etc/localtime` bind mounts;
- persistent `HOST_IP` handling for WireGuard and systemd;
- separate WireGuard configuration directories;
- automatic creation of all log directories;
- validation of the Compose configuration and expected services;
- post-deployment verification of every container state;
- robust replacement of an existing systemd unit;
- pinned Portainer `2.39.5` with `--no-setup-token`.

## Uninstallation

Standard removal:

```bash
sudo ./uninstall_honeynet.sh
```

This removes the stack, its project volumes, the systemd unit, `/etc/default/honeynet`, and `/opt/honeynet`. Docker itself and unrelated Docker resources are preserved.

Optional host-wide Docker cleanup:

```bash
sudo ./uninstall_honeynet.sh --prune
```

Use `--prune` carefully on hosts running other Docker projects.

## Security and research disclaimer

This software intentionally deploys vulnerable or weakly protected services for controlled cybersecurity experimentation. Run it only in an isolated environment and comply with applicable laws, institutional policies, and ethical requirements. The maintainers accept no responsibility for misuse or unsafe deployment.
