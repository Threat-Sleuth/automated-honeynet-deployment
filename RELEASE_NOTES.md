# Extended Honeynet Release Notes

## Main changes

- Expanded the experimental environment from four to eight paired service families.
- Added PostgreSQL in normalidad and pentesting variants.
- Added FastAPI services connected to the corresponding PostgreSQL instances.
- Added SMB file-sharing services.
- Added WireGuard VPN services and web interfaces.
- Preserved duplicated benign/anomalous environments and Fluentd logging tags.
- Added persistent `HOST_IP` handling for WireGuard through `/etc/default/honeynet`.
- Improved systemd startup by using `docker compose up -d`.
- Made Docker-wide pruning optional during uninstallation.

## Compatibility note

The container package supplied for this release is preserved as received. This release work changes deployment, documentation, and release packaging; it does not redesign the service topology or experimental workloads.
