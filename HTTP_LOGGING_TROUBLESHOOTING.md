# HTTP / DVWA Logging Troubleshooting

## Symptom

CAUSALIS sends HTTP traffic and Apache records it in `/var/log/apache2/access.log`, but no JSON records appear in:

- `logs/dvwa_normalidad/dvwa_normalidad.log`
- `logs/dvwa_pentesting/dvwa_pentesting.log`

## Architecture

HTTP traffic reaches DVWA through the two mitmproxy reverse proxies. The mounted addon `/addons/logger.py` serializes each completed response as JSON and appends it to `/logs/dvwa_*.log`. These `/logs` paths are bind-mounted from the host directories above.

## Root cause

The reverse proxies run as the unprivileged `mitmproxy` user (UID/GID 1000). On a clean deployment, the host log directories or files could be created with ownership that allowed root to write but prevented the mitmproxy process from appending. The resulting error was:

```text
PermissionError: [Errno 13] Permission denied: '/logs/dvwa_normalidad.log'
```

or the equivalent pentesting path.

A manual `docker exec ... echo >> /logs/...` test can be misleading because `docker exec` runs as root unless a user is explicitly selected.

## Permanent fix

The installer now creates both directories and both log files before the reverse proxies start, sets directory mode `0775`, file mode `0664`, and ownership `1000:1000` only on the two HTTP logging paths.

No changes were made to DVWA, the reverse-proxy routing, the logger addon format, or other service permissions.

## Validation

```bash
curl -A 'HTTP-LOG-VALIDATION' http://HOST_IP/
curl -A 'HTTP-LOG-VALIDATION' http://HOST_IP:81/

tail -n 5 /opt/honeynet/honeynet/logs/dvwa_normalidad/dvwa_normalidad.log
tail -n 5 /opt/honeynet/honeynet/logs/dvwa_pentesting/dvwa_pentesting.log

docker logs reverse-proxy-normalidad --since 2m
docker logs reverse-proxy-pentesting --since 2m
```

Acceptance criteria:

- both files receive a new JSON record;
- the record contains `HTTP-LOG-VALIDATION`;
- neither proxy reports `Permission denied`.

## Recovery on an existing deployment

```bash
cd /opt/honeynet/honeynet
sudo mkdir -p logs/dvwa_normalidad logs/dvwa_pentesting
sudo touch logs/dvwa_normalidad/dvwa_normalidad.log \
           logs/dvwa_pentesting/dvwa_pentesting.log
sudo chown -R 1000:1000 logs/dvwa_normalidad logs/dvwa_pentesting
sudo chmod 775 logs/dvwa_normalidad logs/dvwa_pentesting
sudo chmod 664 logs/dvwa_normalidad/dvwa_normalidad.log \
               logs/dvwa_pentesting/dvwa_pentesting.log
docker restart reverse-proxy-normalidad reverse-proxy-pentesting
```
