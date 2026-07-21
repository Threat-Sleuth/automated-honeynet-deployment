# Laboratory credentials

These credentials are deliberate defaults for an isolated cybersecurity laboratory. They must never be reused in production or exposed to the public Internet.

## Service credentials

| Service | Environment | Username | Password | Additional value |
|---|---|---|---|---|
| DVWA | normalidad | `admin` | `password` | URL: `http://HOST_IP:80` |
| DVWA | pentesting | `admin` | `password` | URL: `http://HOST_IP:81` |
| FTP | normalidad | `ftpuser` | `password` | Port `2121/tcp` |
| FTP | pentesting | `ftpuser` | `password` | Port `2122/tcp` |
| SSH | normalidad | `root` | `password` | Port `2222/tcp` |
| SSH | pentesting | `root` | `password` | Port `2223/tcp` |
| Mail | normalidad | `usuario1@normalidad.tics` | `password` | SMTP `25`, submission `587`, IMAP `143`, IMAPS `993` |
| Mail | normalidad | `usuario2@normalidad.tics` | `password` | Same ports as above |
| Mail | pentesting | `usuario1@pentesting.tics` | `password` | SMTP `2525`, submission `1587`, IMAP `1143`, IMAPS `1993` |
| Mail | pentesting | `usuario2@pentesting.tics` | `password` | Same ports as above |
| SMB | normalidad | `smbuser` | `password` | Share `share`, port `445/tcp` |
| SMB | pentesting | `smbuser` | `password` | Share `share`, port `1445/tcp` |
| PostgreSQL | normalidad | `normal_user` | `normal_password` | Database `normal_database`, port `5433/tcp` |
| PostgreSQL | pentesting | `pentest_user` | `pentest_password` | Database `pentest_database`, port `5434/tcp` |
| WireGuard UI | normalidad | `admin` | `normalidad-vpn` | UI `http://HOST_IP:51821`, tunnel `51820/udp` |
| WireGuard UI | pentesting | `admin` | `pentesting-vpn` | UI `http://HOST_IP:51823`, tunnel `51822/udp` |

## FastAPI application users

The REST API databases are seeded with synthetic users whose passwords are stored as bcrypt hashes in `restful_api1/db/data/user_data.csv` and `restful_api2/db/data/user_data.csv`. No shared plaintext application password is defined for those seeded accounts. Use the API user-creation endpoint to create a known test account when authenticated application traffic is required.

## Portainer

Portainer does not ship with a predefined administrator password. On first access to `http://localhost:9000`, create the local administrator account through the initial setup screen. Portainer is bound only to loopback.

## Source of truth

The values above are cross-checked against `compose.yml`, service Dockerfiles, Samba initialization, PostgreSQL secret files and docker-mailserver account hashes during release preparation. If any service credential changes, update this document, `README.md`, the corresponding source configuration and `validate_release.sh` in the same commit.
