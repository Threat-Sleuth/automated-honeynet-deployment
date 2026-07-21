# Automated Honeynet v2.1.3

This corrective release preserves the validated v2.1.2 deployment and fixes one confirmed blocker in the SMB service family.

## Confirmed SMB defect

The custom Samba image enabled `vfs objects = full_audit`, but installed only the base Samba packages. On Debian Bookworm, the `full_audit.so` module is delivered by the separate `samba-vfs-modules` package. Authentication therefore succeeded, but Samba could not initialize the `[shared]` resource and returned `NT_STATUS_BAD_NETWORK_NAME`. As a result, no real file operations or SMB audit telemetry could be produced.

## Corrective change

The custom SMB image now installs `samba-vfs-modules`. The installer verifies at runtime that both `smb-normalidad` and `smb-pentesting` contain `full_audit.so` before reporting a successful deployment. Release validation also rejects future packages that omit either safeguard.

No ports, credentials, service names, Docker networks, Fluentd tags, WireGuard configuration, API/database secrets, mail configuration, DVWA telemetry handling or other service behavior have been changed.

## Validation required after installation

Run a real SMB file-operation sequence against the `shared` resource on ports `445` and `1445`, then verify audit events in Docker and Fluentd logs. The release remains intended exclusively for isolated and authorized cybersecurity experimentation.
