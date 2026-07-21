# Automated Honeynet v2.1.1

This patch release provides a reproducible Docker-based laboratory honeynet with paired normalidad and pentesting environments for DVWA, FTP, SSH, mail, PostgreSQL, FastAPI, SMB and WireGuard.

## Corrective changes

- Replaced the unavailable `ghcr.io/wg-easy/wg-easy:14.0.0` image with the published stable image `ghcr.io/wg-easy/wg-easy:15.3.0`.
- Migrated both WireGuard services to the wg-easy v15 configuration model.
- Removed legacy v14 variables (`WG_HOST`, `WG_DEVICE` and `PASSWORD_HASH`).
- Added v15 unattended initialization with distinct laboratory credentials and independent server ports.
- Added `INSECURE=true` because the laboratory UI is intentionally served over HTTP inside the isolated VM.
- Added the official `/lib/modules` read-only mount and the complete forwarding sysctl set used by wg-easy v15.
- Preserved independent WireGuard state directories and structured collectors for both environments.
- Preserved independent SMB mutable shares, isolated mitmproxy state, separate REST secrets and clean runtime directories.
- Regenerated `honeynet.tar.gz`, every release checksum and the complete ZIP from one consistent source tree.
- Extended release validation to reject the obsolete wg-easy v14 variables, incorrect WireGuard port mappings and any image other than the pinned `15.3.0` release.

The release is intended only for isolated and authorized cybersecurity experimentation. Validate it on a clean Ubuntu VM and run a short CAUSALIS campaign before freezing it as the experimental baseline.
