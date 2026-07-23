# Changelog

## [2.1.3] - 2026-07-23

### Fixed — SMB

- Installed `samba-vfs-modules` in the custom Samba image.
- Removed the Samba 4.17-incompatible `full_audit` operation list.
- Replaced syslog-dependent VFS auditing with native Samba stdout logging (`log level = 3 auth_audit:3`) for direct Docker/Fluentd collection.
- Validated authentication, listing, upload, download, rename, directory creation/removal and file deletion.

### Fixed — WireGuard

- Documented and validated safe recovery from an inconsistent `wg-easy.db`.
- Confirmed clean unattended initialization through `INIT_*` variables and installer-provided `HOST_IP`.
- Validated real peer creation, profile export, handshake, bidirectional transfer and tunnel connectivity.
- Documented Kali client requirements and the `resolvconf`/DNS-profile workaround.

### Fixed — HTTP / DVWA telemetry

- Preserved the existing mitmproxy reverse-proxy and JSON logger design.
- Fixed clean-deployment ownership of `logs/dvwa_normalidad` and `logs/dvwa_pentesting`.
- Pre-created both JSON log files with UID/GID 1000, directory mode `0775`, and file mode `0664`.
- Validated JSON telemetry for both normalidad and pentesting without changing any working service behavior.

### Documentation and validation

- Added `SMB_WIREGUARD_TROUBLESHOOTING.md`.
- Added `scripts/validate_smb_wireguard.sh`.
- Updated release metadata and checksums.

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
