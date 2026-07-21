# Changelog

## 2.1.2 — 2026-07-21

- Fixed the DVWA/mitmproxy telemetry regression caused by hardened `0775` log-directory permissions without matching runtime ownership.
- Explicitly assigns `logs/dvwa_normalidad` and `logs/dvwa_pentesting` to UID/GID `1000:1000` during clean installation.
- Added an installation-time write test for both reverse-proxy `/logs` mounts.
- Added `CREDENTIALS.md` as the canonical service-credential reference.
- Cross-checked and documented DVWA, FTP, SSH, mail, SMB, PostgreSQL and WireGuard UI credentials and clarified Portainer and FastAPI account behavior.
- Extended release validation to reject missing credential documentation and missing mitmproxy ownership/write-test safeguards.
- Regenerated the complete project archive, checksums and release ZIP from one source tree.

## 2.1.1 — 2026-07-21

- Replaced the unavailable wg-easy `14.0.0` image with the published stable `15.3.0` release.
- Migrated both WireGuard services from legacy v14 variables to the v15 unattended initialization model.
- Assigned independent WireGuard server ports and distinct laboratory credentials to normalidad and pentesting.
- Added the wg-easy v15 module mount, forwarding sysctls and HTTP laboratory UI setting.
- Updated validation to reject legacy wg-easy variables, invalid port mappings and incorrect image tags.
- Regenerated the internal TAR archive, release metadata, documentation and checksums as one coherent package.

## 2.1.0 — 2026-07-20

- Expanded the reproducible honeynet to eight paired service families.
- Added PostgreSQL and FastAPI service pairs.
- Added SMB service pairs with custom Samba `full_audit` telemetry.
- Added WireGuard service pairs and structured peer-state collectors for both environments.
- Added Fluentd routes for database, API, SMB and VPN telemetry.
- Added release, architecture, logging, reproducibility and troubleshooting documentation.
- Hardened installation, verification, service management and uninstallation scripts.
- Added automated deployment and release validation scripts.
- Removed persisted WireGuard secrets and prior mail-server runtime state from the release archive.
- Pinned external image versions used by mitmproxy, docker-mailserver and wg-easy.
- Added release validation guards against embedded WireGuard secrets, mail-state leakage and `latest` image tags.
- Removed generated mitmproxy CA/private-key artefacts from the distribution.
- Separated normalidad and pentesting database/JWT Docker secrets.
- Extended release validation for PEM/PKCS#12 private material and duplicate REST secrets.
- Isolated mitmproxy CA/configuration state for normalidad and pentesting at runtime.
- Removed the residual WireGuard password-hash file and assigned distinct web-UI credentials to each environment.
- Updated `.gitignore` so required laboratory Docker secret files remain versioned.
- Extended release validation to reject shared mitmproxy mounts and duplicated WireGuard UI credentials.
- Isolated SMB mutable storage into independent normalidad and pentesting shares.
- Removed obsolete webcam log directories and legacy media artefacts.
- Hardened generated log-directory permissions from world-writable `0777` to group-writable `0775`.
- Extended release validation to reject shared SMB storage and obsolete webcam/media paths.
