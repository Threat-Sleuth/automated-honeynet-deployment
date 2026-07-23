# Automated Honeynet Deployment v2.1.3

## Stable Research Baseline

Version 2.1.3 consolidates the complete honeynet package after end-to-end validation of the two services that previously blocked full experimental campaigns: SMB and WireGuard.

### Fixed — SMB

- The custom image now installs `samba-vfs-modules`.
- The incompatible `full_audit` configuration has been removed.
- Samba writes native authentication and connection telemetry to stdout, which Docker forwards to Fluentd.
- Real authentication and file operations were validated: listing, upload, download, rename, directory creation/removal and deletion.

### Fixed — WireGuard

- WG-Easy persisted-state recovery is documented and reproducible.
- Clean deployments initialize from the installer-detected host IP and the configured `INIT_*` values.
- Real client creation, profile export, tunnel establishment, handshake and bidirectional traffic were validated.
- Kali client installation and the optional removal of the generated DNS line are documented.

### Fixed — HTTP / DVWA telemetry

- Clean installations now create the two mitmproxy JSON log paths with the ownership expected by the pinned mitmproxy image.
- Both normalidad and pentesting HTTP requests were validated end to end from reverse proxy to persistent JSON file.
- The fix is deliberately limited to the two DVWA log directories and files.

### Complete package

The release includes all services, source directories, deployment and removal scripts, systemd unit, Fluentd configuration, health checks, validation scripts, credentials documentation, service ports, troubleshooting documentation and integrity checksums.

Read `SMB_WIREGUARD_TROUBLESHOOTING.md` before reproducing the SMB and VPN acceptance tests.
