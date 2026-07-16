# Extended Honeynet v2.0.4

## Release status

This is the first release of the extended honeynet validated end-to-end on a clean Ubuntu virtual machine with the complete stack running.

Validation result:

- 20 containers running;
- 0 stopped containers;
- 0 unhealthy containers;
- 4 containers reporting healthy status through configured health checks;
- systemd service installed and enabled;
- Portainer operational;
- all normal and pentesting log directories created.

## Main expansion

The original four paired service families have been expanded to eight:

- HTTP/DVWA;
- FTP;
- SSH;
- SMTP/IMAP mail;
- PostgreSQL;
- FastAPI REST API;
- SMB;
- WireGuard VPN.

Each family is duplicated into `normalidad` and `pentesting` environments. PostgreSQL can be accessed directly or indirectly through the corresponding FastAPI service.

## Deployment and reproducibility fixes

- Added automatic creation of every log directory and Fluentd buffer directory.
- Added persistent `HOST_IP` handling through `/etc/default/honeynet`.
- Added Compose validation before deployment.
- Added verification that all 20 expected services are present.
- Added a post-deployment wait and state check for every expected container.
- Added automatic diagnostic output when a container does not reach the running state.
- Replaced the invalid Fluentd option `fluentd-async-connect` with `fluentd-async`.
- Removed incompatible `/etc/timezone` and `/etc/localtime` bind mounts.
- Separated normal and pentesting WireGuard configuration directories.
- Corrected the installer variable collision that caused `portainer` to be treated as the systemd unit source.
- Made systemd unit replacement robust against stale files, links, or directories.
- Pinned Portainer Community Edition to `2.39.5`.
- Added `--no-setup-token` to preserve browser-based initial administrator creation.
- Made Docker-wide pruning optional during uninstallation.

## Resource requirement discovered during validation

The complete 20-container stack requires more resources than the original deployment. The validated minimum recommendation is:

- 4 vCPU;
- 8 GB RAM;
- 30 GB free disk space.

A 4 GB virtual machine became unresponsive during full-stack startup; increasing memory to 8 GB allowed the deployment and Portainer validation to complete successfully.

## Compatibility

Validated primarily on Ubuntu 24.04 LTS with Docker Compose v2. Other supported distribution families remain best-effort.

## Security notice

The included credentials and deliberately vulnerable services are intended only for isolated laboratory use. Do not expose the stack directly to the public Internet.
