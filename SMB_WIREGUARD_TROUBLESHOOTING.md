# SMB and WireGuard troubleshooting and validation

This document records the two service-level issues corrected and validated for the v2.1.3 stable research baseline. It is intended both as a deployment guide and as an auditable record of the diagnostic process.

## 1. SMB

### 1.1 Symptoms

The Samba containers started and accepted the `smbuser` credentials, but the `shared` resource could not be mounted. Clients first received `NT_STATUS_BAD_NETWORK_NAME`, and after the VFS module was installed they received `NT_STATUS_UNSUCCESSFUL`.

Representative server errors were:

```text
Error loading module .../samba/vfs/full_audit.so
vfs_init_custom failed for full_audit
make_connection_snum: vfs_init failed for service shared
```

After installing the module, the remaining error was:

```text
smb_full_audit_connect: Invalid success operations list. Failing connect
Could not find opname opendir
```

### 1.2 Root causes

Two independent causes were confirmed:

1. The custom Samba image did not install `samba-vfs-modules`, so `full_audit.so` was absent.
2. The configured `full_audit:success` operation list was incompatible with Samba 4.17. In addition, `full_audit` writes through syslog, while the container had no syslog daemon; therefore its events could not reach Docker's Fluentd logging driver.

### 1.3 Final solution

The v2.1.3 image installs `samba-vfs-modules` so the Samba package set is complete, but the runtime configuration deliberately uses native Samba logging instead of `vfs_full_audit`:

```ini
logging = stdout
log level = 3 auth_audit:3
```

All `vfs objects = full_audit` and `full_audit:*` settings were removed. This avoids an unnecessary syslog process and sends authentication, connection, origin, user and session events directly to stdout, from where Docker forwards them to Fluentd.

The exact semantic operation executed by a campaign (`put`, `rename`, `mkdir`, `del`, and so on) is recorded by CAUSALIS. The server logs provide the independent service-side evidence.

### 1.4 Validated operations

The following operations were executed successfully against the pentesting service on host port `1445`:

```text
authenticate
ls
put
get (after setting a writable local directory with lcd /tmp)
rename
mkdir
rmdir
del
```

Example client command:

```bash
smbclient //HOST/shared -p 1445 -U smbuser
```

Default password:

```text
password
```

The normality service uses host port `445`.

### 1.5 Log validation

The containers use the Docker Fluentd logging driver. Validate newly written files with:

```bash
find /opt/honeynet/honeynet/logs/smb_pentesting -type f -mmin -5 -print
find /opt/honeynet/honeynet/logs/smb_normalidad -type f -mmin -5 -print
```

Search for authentication and connection evidence:

```bash
grep -RniE 'Auth:|smbuser|connected|closed connection' \
  /opt/honeynet/honeynet/logs/smb_* 2>/dev/null | tail -100
```

## 2. WireGuard / WG-Easy

### 2.1 Symptoms

The WireGuard server interfaces existed and listened on the expected UDP ports, but the WG-Easy interface displayed:

```text
Session failed. No Authorization
```

No peers or handshakes were visible in `wg show`. Accessing the web UI alone generated no WireGuard tunnel traffic.

### 2.2 Root causes

The protocol server itself was healthy. The operational problems were:

1. An inconsistent persisted `wg-easy.db` prevented valid WG-Easy authorization.
2. No real WireGuard client had been created and connected.
3. On Kali, `wireguard-tools` was initially absent.
4. The exported client profile contained a `DNS = ...` line. Kali's `resolvconf` integration failed with a signature mismatch, causing `wg-quick` to remove the interface after creating it.

The CLI reset command in the tested `wg-easy:15.3.0` image was not usable because the image's CLI failed with a missing Node dependency (`citty`). The reliable recovery procedure is therefore database regeneration after backup.

### 2.3 Safe WG-Easy recovery procedure

Use the Compose service name, not the container name.

Pentesting service:

```bash
cd /opt/honeynet/honeynet
sudo docker compose stop wireguard_pentesting
BACKUP_DIR="vpn/backup_pentesting_$(date +%Y%m%d_%H%M%S)"
sudo mkdir -p "$BACKUP_DIR"
sudo cp -a vpn/wireguard_pentesting/. "$BACKUP_DIR/"
sudo rm -f vpn/wireguard_pentesting/wg-easy.db
sudo docker compose up -d --force-recreate wireguard_pentesting
```

Normality service:

```bash
sudo docker compose stop wireguard_normalidad
BACKUP_DIR="vpn/backup_normalidad_$(date +%Y%m%d_%H%M%S)"
sudo mkdir -p "$BACKUP_DIR"
sudo cp -a vpn/wireguard_normalidad/. "$BACKUP_DIR/"
sudo rm -f vpn/wireguard_normalidad/wg-easy.db
sudo docker compose up -d --force-recreate wireguard_normalidad
```

The installer creates clean runtime directories, so a clean deployment starts without a persisted database and WG-Easy initializes from the `INIT_*` variables.

### 2.4 Server endpoints

| Profile | WireGuard UDP | WG-Easy UI |
|---|---:|---:|
| Normality | 51820 | 51821 |
| Pentesting | 51822 | 51823 |

The installer detects the host IPv4 address and writes it to `/etc/default/honeynet` as `HOST_IP`. Running Compose manually without loading this environment can produce `HOST_IP is not set` warnings and an unusable exported endpoint.

### 2.5 Kali client preparation

```bash
sudo apt update
sudo apt install -y wireguard wireguard-tools
sudo mkdir -p /etc/wireguard
sudo cp ~/Downloads/causalis-test.conf /etc/wireguard/
sudo chmod 600 /etc/wireguard/causalis-test.conf
```

For experimental traffic generation, remove the `DNS = ...` line from the downloaded profile if the client reports a `resolvconf` error. DNS modification is not required to validate the tunnel or generate traffic.

Then start the tunnel:

```bash
sudo wg-quick up causalis-test
```

### 2.6 Validated tunnel test

Generate traffic:

```bash
ping -c 5 10.8.0.1
```

Validate on Kali:

```bash
sudo wg show causalis-test
```

Validate on the server:

```bash
docker exec vpn_pentesting wg show
```

Acceptance evidence must include:

```text
latest handshake: ...
transfer: ... received, ... sent
```

The validated test achieved bidirectional tunnel traffic and 0% packet loss to `10.8.0.1`. Host capture also confirmed bidirectional UDP traffic and Docker DNAT to the WireGuard container.

### 2.7 Important distinction for CAUSALIS

Opening the WG-Easy web interface is not WireGuard traffic. A campaign must create or provision a peer, obtain a client profile, bring up a real tunnel, send packets through it, and then bring the tunnel down. This change belongs to CAUSALIS; the v2.1.3 honeynet provides the validated server infrastructure.

## 3. Release acceptance checklist

### SMB

- `samba-vfs-modules` installed in the image.
- No `full_audit` runtime configuration.
- Native stdout logging enabled.
- Authentication and file operations work.
- Fluentd writes new SMB logs for both profiles.

### WireGuard

- Both `wg0` interfaces are present and listening.
- WG-Easy initializes cleanly from `INIT_*` values.
- Client creation and configuration export work.
- A real client establishes a handshake.
- RX and TX counters increase on both client and server.
- `ping 10.8.0.1` succeeds through the tunnel.
