# Extended Honeynet v2.0.3

## Fixed

- Replaced the invalid Docker Fluentd logging option `fluentd-async-connect` with the supported option `fluentd-async`.
- Preserved all 20 Docker Compose services: eight duplicated experimental service families plus Fluentd, two mitmproxy reverse proxies, and Portainer.
- Preserved automatic creation of all normalidad/pentesting log directories and their buffer subdirectories.
- Preserved post-deployment validation that checks every expected container and reports failures.

## Service families

- HTTP/DVWA
- FTP
- SSH
- SMTP/IMAP mail
- PostgreSQL
- FastAPI REST API
- SMB
- WireGuard VPN

Each service family is duplicated for `normalidad` and `pentesting` traffic.
