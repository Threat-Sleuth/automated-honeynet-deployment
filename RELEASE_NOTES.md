# Automated Honeynet v2.1.2

This corrective release preserves the validated v2.1.1 deployment while fixing one isolated regression in HTTP telemetry.

## Corrective change

The v2.1.1 installer created all log directories with mode `0775`, but the two DVWA directories remained owned by the host account. The mitmproxy containers therefore received and forwarded HTTP traffic correctly but could not append JSON events to `/logs/dvwa_normalidad.log` or `/logs/dvwa_pentesting.log`.

v2.1.2 explicitly assigns both DVWA log mounts to mitmproxy UID/GID `1000:1000` and performs a write test from each reverse-proxy container before declaring installation successful. No SMB, WireGuard, mail, database, API, FTP, SSH or Fluentd configuration has been changed.

## Credential documentation

`CREDENTIALS.md` is now the canonical reference for every predefined laboratory credential. It distinguishes fixed service credentials, separate environment-specific database and WireGuard values, first-run Portainer setup and FastAPI seed users that do not have a shared plaintext password.

The release remains intended exclusively for isolated and authorized cybersecurity experimentation.
