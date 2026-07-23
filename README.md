# Automated Honeynet Deployment

A reproducible Docker-based honeynet for controlled cybersecurity experimentation, attack-event capture, log collection, and dataset generation. The platform deploys paired **normal-traffic** and **pentesting** environments so that CAUSALIS or another traffic generator can produce comparable benign and anomalous activity.

> **Laboratory use only.** The stack intentionally includes vulnerable services and weak credentials. Deploy it only on an isolated host or virtual machine. Never expose it directly to the public Internet.

## Release scope

This release provides eight duplicated service families:

- DVWA web application behind mitmproxy;
- FTP;
- SSH;
- mail server;
- PostgreSQL;
- FastAPI REST API;
- SMB;
- WireGuard.

Supporting components include Fluentd for central log collection, Portainer for local container administration, a custom Samba image with VFS audit logging, and a WireGuard telemetry collector that converts peer state into structured JSON events.

## Architecture

```text
                         CAUSALIS / traffic clients
                                    |
                    +---------------+---------------+
                    |                               |
             normalidad network              pentesting network
                    |                               |
      +-------------+-------------+   +-------------+-------------+
      | DVWA | FTP | SSH | Mail   |   | DVWA | FTP | SSH | Mail   |
      | DB   | API | SMB | WG     |   | DB   | API | SMB | WG     |
      +-------------+-------------+   +-------------+-------------+
                    |                               |
                    +---------------+---------------+
                                    |
                        Docker logging / mitmproxy
                                    |
                                 Fluentd
                                    |
                  /opt/honeynet/honeynet/logs/<service>/
                                    |
                      processing, datasets and ML
```

The `normalidad` and `pentesting` Docker bridge networks isolate the two traffic classes. Infrastructure services use the default Compose network where appropriate.

## Host requirements

Recommended clean virtual machine:

- Ubuntu 22.04 or 24.04 LTS;
- 4 vCPUs;
- 8 GiB RAM;
- at least 12 GiB free disk space;
- Internet access during installation;
- root or `sudo` privileges;
- no conflicting services on the published ports.

The installer refuses deployment below 6 GiB of RAM or 12 GiB of free disk space. Docker Engine and the Docker Compose plugin are installed automatically on supported distributions when absent. External container images are pinned to explicit versions in `compose.yml` to prevent silent changes between deployments.

## Distribution files

```text
README.md
RELEASE_NOTES.md
SERVICE_PORTS.txt
SHA256SUMS
honeynet.service
honeynet.tar.gz
install_honeynet.sh
uninstall_honeynet.sh
```

`honeynet.tar.gz` must contain the project as `honeynet/`, including `compose.yml` and every service directory.

## Release hygiene

The distribution does not include generated mitmproxy certificate authorities, private keys, WireGuard state, mail runtime state, databases, logs or Docker volumes. Each mitmproxy instance creates a fresh, independent CA on first start in an environment-specific directory. The two REST environments use separate Docker secret objects and distinct database/JWT values. The WireGuard web interfaces also use distinct laboratory credentials and no generated password-hash file is distributed. SMB uses independent mutable share directories for normalidad and pentesting, preventing file-state contamination between traffic classes. Obsolete webcam and legacy media directories are not included. wg-easy is pinned to `15.3.0` and configured with the v15 unattended setup interface (`INIT_*` variables), avoiding the incompatible v14 `WG_HOST`, `WG_DEVICE` and `PASSWORD_HASH` variables.

## Installation

Extract the GitHub release archive and run:

```bash
chmod +x install_honeynet.sh uninstall_honeynet.sh
sudo ./install_honeynet.sh
```

The installer performs the following operations:

1. checks CPU, memory and free disk space;
2. verifies `honeynet.tar.gz` and `SHA256SUMS`;
3. installs or validates Docker Engine and Docker Compose;
4. stops a previous honeynet deployment safely;
5. extracts the project into `/opt/honeynet/honeynet`;
6. creates clean mail-state and independent WireGuard runtime directories;
7. creates all log and Fluentd buffer directories;
8. detects the host IPv4 address and writes `/etc/default/honeynet`;
9. validates `compose.yml` and the required services;
10. builds local images, including custom Samba and the WireGuard collector;
11. starts the stack and verifies every long-running service;
12. installs and enables `honeynet.service`.

Successful completion ends with:

```text
[OK] Honeynet installation completed successfully.
```

## Service ports

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
| WireGuard web UI | `51821/tcp` | `51823/tcp` |

Infrastructure ports:

- Fluentd: `24224/tcp` and `24224/udp`;
- Portainer: `127.0.0.1:9000/tcp`.

See `SERVICE_PORTS.txt` for the compact reference used during deployment and traffic-profile configuration.

## Default laboratory credentials

| Service | Username | Password / database |
|---|---|---|
| DVWA | `admin` | `password` |
| FTP | `ftpuser` | `password` |
| SSH | `root` | `password` |
| Mail | `usuario1` / `usuario2` | `password` |
| SMB | `smbuser` | `password` |
| PostgreSQL (normalidad) | `normal_user` | `normal_password` |
| PostgreSQL database (normalidad) | — | `normal_database` |
| PostgreSQL (pentesting) | `pentest_user` | `pentest_password` |
| PostgreSQL database (pentesting) | — | `pentest_database` |

Mail domains:

- `normalidad.tics`
- `pentesting.tics`

The release retains only account configuration. Mailboxes and Postfix/Dovecot runtime state are created from empty directories during installation and are not shipped from previous deployments.

These credentials are deliberate laboratory defaults, not production settings.

WireGuard web UI laboratory credentials:

- normalidad: `normalidad-vpn`;
- pentesting: `pentesting-vpn`.

The two wg-easy instances use the v15 unattended-initialization variables on first start. Both use username `admin` with distinct laboratory passwords. The normalidad server is initialized for UDP port `51820`; the pentesting server is initialized for UDP port `51822`. No generated WireGuard configuration, private key or peer database is distributed.

## Verification

Check the systemd unit and container state:

```bash
sudo systemctl status honeynet.service
cd /opt/honeynet/honeynet
sudo bash -c 'set -a; source /etc/default/honeynet; set +a; docker compose ps'
```

Basic application tests, replacing `HOST_IP` with the VM address:

```bash
curl -I http://HOST_IP:80
curl -I http://HOST_IP:81
curl -fsS http://HOST_IP:8000/docs >/dev/null
curl -fsS http://HOST_IP:8001/docs >/dev/null
nc -zv HOST_IP 5433
nc -zv HOST_IP 5434
nc -zv HOST_IP 445
nc -zv HOST_IP 1445
curl -fsS http://HOST_IP:51821 >/dev/null
curl -fsS http://HOST_IP:51823 >/dev/null
```

Inspect recent logs:

```bash
cd /opt/honeynet/honeynet
sudo docker compose logs --tail=100
find logs -type f -maxdepth 4 -print
```

## SMB telemetry

The normal-traffic SMB service uses the custom `honeynet-samba` image and Samba's `full_audit` VFS module. Normalidad and pentesting mount separate host directories (`smb/share_normalidad/` and `smb/share_pentesting/`) so file changes in one environment cannot affect the other. Operations such as connections, file creation, reads, writes, metadata access, renames and deletions are emitted to container stdout and forwarded to Fluentd with the tag:

```text
normalidad.smb
```

The pentesting instance uses:

```text
pentesting.smb
```

Resulting data is stored below:

```text
/opt/honeynet/honeynet/logs/smb_normalidad/
/opt/honeynet/honeynet/logs/smb_pentesting/
```

## WireGuard telemetry

WireGuard does not normally emit useful peer activity to container stdout. Both environments include dedicated collectors: `wg_collector_normalidad` and `wg_collector_pentesting`, which polls:

```bash
wg show all dump
```

It emits a JSON event whenever a peer endpoint, handshake time, received-byte count or transmitted-byte count changes. Example structure:

```json
{
  "timestamp": "2026-07-20T08:00:00Z",
  "service": "wireguard",
  "interface": "wg0",
  "peer": "PUBLIC_KEY",
  "endpoint": "172.20.0.11:38155",
  "allowed_ips": "10.8.0.2/32",
  "latest_handshake": 1784552122,
  "rx_bytes": 788,
  "tx_bytes": 880
}
```

Events are forwarded to Fluentd using `normalidad.vpn` or `pentesting.vpn` and written under the corresponding VPN log directory:

```text
/opt/honeynet/honeynet/logs/vpn_normalidad/
/opt/honeynet/honeynet/logs/vpn_pentesting/
```

Server private keys, preshared keys and peer databases are **not** distributed in the release archive. Each clean deployment initializes independent runtime state for the normalidad and pentesting WireGuard instances. Do not publish files generated below `vpn/wireguard_normalidad/` or `vpn/wireguard_pentesting/`.

The bundled `wg-client` is a laboratory traffic helper. It may be configured as a one-shot client and therefore is not treated as a permanently running service by the installer.

## Logging

Fluentd receives environment- and service-specific tags:

```text
normalidad.ssh          pentesting.ssh
normalidad.ftp          pentesting.ftp
normalidad.mailserver   pentesting.mailserver
normalidad.db           pentesting.db
normalidad.api          pentesting.api
normalidad.smb          pentesting.smb
normalidad.vpn          pentesting.vpn
```

DVWA HTTP traffic is recorded separately by each mitmproxy reverse proxy. Persistent logs are stored below:

```text
/opt/honeynet/honeynet/logs/
```

## Portainer

Portainer is available only from the honeynet host:

```text
http://localhost:9000
```

It is intentionally bound to `127.0.0.1`. Use an SSH tunnel when administration from another machine is necessary.

## Service management

```bash
sudo systemctl start honeynet.service
sudo systemctl stop honeynet.service
sudo systemctl restart honeynet.service
sudo systemctl status honeynet.service
```

Direct Compose management:

```bash
sudo bash -c '
  set -a
  source /etc/default/honeynet
  set +a
  cd /opt/honeynet/honeynet
  docker compose ps
'
```

## Host IP changes

The installer writes the detected address to:

```text
/etc/default/honeynet
```

Example:

```bash
HOST_IP=192.0.2.10
```

When the VM address changes, edit that file and restart the stack:

```bash
sudo nano /etc/default/honeynet
sudo systemctl restart honeynet.service
```

## Uninstallation

Standard removal preserves Docker Engine and downloaded/built images:

```bash
sudo ./uninstall_honeynet.sh
```

Remove project-built images as well:

```bash
sudo ./uninstall_honeynet.sh --remove-images
```

Host-wide Docker cleanup is available only for a dedicated laboratory VM:

```bash
sudo ./uninstall_honeynet.sh --remove-images --prune
```

`--prune` may delete unused Docker resources belonging to other projects.

## Short validation campaign

After a clean installation:

1. confirm all long-running containers are `running`;
2. create normal and anomalous traffic against every service with CAUSALIS;
3. verify new files or Fluentd buffers appear in all sixteen service log directories;
4. inspect SMB audit events and WireGuard JSON state-change events;
5. process the logs and export a small train/test dataset;
6. verify that binary and multiclass processing complete without missing-service errors.

Only tag and publish the GitHub release after this clean-machine validation succeeds.

## Troubleshooting

### Compose validation fails

```bash
cd /opt/honeynet/honeynet
sudo bash -c 'set -a; source /etc/default/honeynet; set +a; docker compose config'
```

### A container is not running

```bash
cd /opt/honeynet/honeynet
sudo docker compose ps -a
sudo docker compose logs --tail=150 SERVICE_NAME
```

### Fluentd connection errors

```bash
sudo docker logs fluentd --tail=150
sudo ss -lntup | grep 24224
```

### WireGuard has no events

Confirm that at least one peer exists and has completed a handshake:

```bash
sudo docker exec vpn_normalidad wg show
sudo docker exec vpn_normalidad wg show all dump
```

### SMB has no audit operations

Generate a real file operation rather than only checking that port 445 is open, then inspect:

```bash
sudo docker logs smb-normalidad --tail=150
```

## Security and research disclaimer

This software intentionally deploys vulnerable or weakly protected services for controlled cybersecurity experimentation. Operators are responsible for network isolation, authorization, legal compliance, institutional approval, safe traffic generation, and protection of generated datasets. The project must not be used to attack third-party systems.

## v2.1.3 stable research baseline

This release consolidates the fully validated SMB and WireGuard services. The complete diagnostic record and recovery procedures are provided in [`SMB_WIREGUARD_TROUBLESHOOTING.md`](SMB_WIREGUARD_TROUBLESHOOTING.md) and inside the installed project under `docs/`.

Key outcomes:

- SMB authentication, listing, upload, download, rename, directory creation/removal and deletion validated.
- Native Samba stdout logging delivered to Fluentd without a syslog sidecar.
- WG-Easy clean initialization and database recovery documented.
- Real WireGuard peer creation, handshake, bidirectional transfer and tunnel connectivity validated.
