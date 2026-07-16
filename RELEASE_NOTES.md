# Extended Honeynet v2.0.1

## Corrective release

This release fixes deployment robustness for the expanded eight-service honeynet.

### Fixes

- The installer now explicitly creates every normalidad and pentesting log directory before Docker Compose starts.
- Buffer subdirectories required by Fluentd are also created automatically.
- `.gitkeep` files are included in all log directories so Git and GitHub preserve the directory tree.
- The installer validates that all 20 expected Compose services are present before deployment.
- `HOST_IP` persistence for WireGuard is retained through `/etc/default/honeynet`.

### Expanded services

HTTP/DVWA, FTP, SSH, mail, PostgreSQL, FastAPI, SMB and WireGuard, each duplicated for normal and anomalous traffic.

## v2.0.2 deployment hardening

- Verifies at runtime that all 20 expected containers are created and remain in `running` state.
- Stops installation with diagnostic logs if any service is missing, exited, dead, or restarting.
- Enables asynchronous Fluentd connection for service logging so initial container creation does not fail while Fluentd starts.
- Separates WireGuard state into independent normalidad and pentesting directories.
- Removes embedded `.git` metadata from the deployment archive.
