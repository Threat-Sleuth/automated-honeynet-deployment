# Automated Honeynet v2.1.0

This release provides a reproducible, Docker-based laboratory honeynet with paired normalidad and pentesting environments for eight service families: DVWA, FTP, SSH, mail, PostgreSQL, FastAPI, SMB and WireGuard.

Key additions are audited SMB operations through Samba `full_audit`, structured WireGuard peer-state events, expanded Fluentd routing, improved clean-machine installation checks, systemd lifecycle management and reproducibility documentation.

The release is intended exclusively for isolated and authorized cybersecurity experimentation. Complete a clean Ubuntu deployment and a short CAUSALIS campaign before using it as an experimental baseline or publishing the GitHub tag.


Reproducibility and packaging safeguards in this build:

- no WireGuard private keys, preshared keys or generated peer databases are included;
- no mailboxes or prior Postfix/Dovecot runtime state are included;
- mitmproxy, docker-mailserver and wg-easy use explicit image tags rather than `latest`;
- both WireGuard collectors are required and verified by the installer.
- generated mitmproxy CA and private-key material are excluded and recreated at first start;
- normalidad and pentesting REST/database services use separate secret objects and distinct values;
- release validation rejects private-key material, PKCS#12 files, duplicated REST secrets and stale runtime artefacts.
- mitmproxy now uses independent runtime configuration directories for normalidad and pentesting;
- the two WireGuard web interfaces use distinct laboratory credentials and no residual hash file is distributed;
- Git ignore rules explicitly retain the REST secret inputs required for reproducible deployment.
- SMB normalidad and pentesting services now use independent mutable share directories to prevent cross-environment contamination.
- Obsolete webcam and legacy media directories have been removed from the clean release.
- Log directory permissions are created as `0775` instead of `0777`.
- Release validation now rejects shared SMB mounts and legacy webcam/media artefacts.
