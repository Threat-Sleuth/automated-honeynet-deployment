#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}"
cd "$ROOT"
required=(README.md CREDENTIALS.md RELEASE_NOTES.md CHANGELOG.md VERSION LICENSE CITATION.cff SECURITY.md CONTRIBUTING.md SERVICE_PORTS.txt honeynet.service honeynet.tar.gz install_honeynet.sh uninstall_honeynet.sh)
for f in "${required[@]}"; do [[ -s "$f" ]] || { echo "[FAIL] Missing or empty: $f" >&2; exit 1; }; done
bash -n install_honeynet.sh uninstall_honeynet.sh validate_release.sh

# Require the validated mitmproxy ownership and runtime write-test safeguards.
grep -Fq '"${PROJECT_DIR}/logs/dvwa_normalidad"' install_honeynet.sh || { echo '[FAIL] Installer lacks DVWA normalidad ownership handling.' >&2; exit 1; }
grep -Fq '"${PROJECT_DIR}/logs/dvwa_pentesting"' install_honeynet.sh || { echo '[FAIL] Installer lacks DVWA pentesting ownership handling.' >&2; exit 1; }
grep -Fq 'verify_telemetry_writability' install_honeynet.sh || { echo '[FAIL] Installer lacks mitmproxy telemetry write verification.' >&2; exit 1; }

tar -tzf honeynet.tar.gz >/dev/null
archive_list=$(mktemp)
tmp=$(mktemp -d)
trap 'rm -f "$archive_list"; rm -rf "$tmp"' EXIT
tar -tzf honeynet.tar.gz > "$archive_list"
grep -Fx 'honeynet/compose.yml' "$archive_list" >/dev/null || { echo '[FAIL] honeynet/compose.yml is missing.' >&2; exit 1; }
if grep -E '(^|/)\.\./|^/' "$archive_list" >/dev/null; then echo '[FAIL] Unsafe path found in archive.' >&2; exit 1; fi
tar -xzf honeynet.tar.gz -C "$tmp"
PROJECT="$tmp/honeynet"

# Reject private key/certificate bundles and generated runtime state.
if grep -RIlE --binary-files=without-match 'BEGIN (RSA |EC |OPENSSH |)?PRIVATE KEY|^[[:space:]]*(PrivateKey|PresharedKey)[[:space:]]*=' "$PROJECT" 2>/dev/null | grep -q .; then
  echo '[FAIL] Private-key material found in release archive.' >&2; exit 1
fi
if find "$PROJECT" -type f \( -iname '*.p12' -o -iname '*.pfx' -o -iname '*.key' \) -print -quit | grep -q .; then
  echo '[FAIL] PKCS#12/PFX/private-key file found in release archive.' >&2; exit 1
fi
for env in normalidad pentesting; do
  [[ -d "$PROJECT/mitmproxy/config/$env" ]] || { echo "[FAIL] Missing isolated mitmproxy config directory: $env." >&2; exit 1; }
done
if find "$PROJECT/mitmproxy/config" -type f ! -name '.gitkeep' -print -quit | grep -q .; then
  echo '[FAIL] Generated mitmproxy CA/config state found in release archive.' >&2; exit 1
fi
if find "$PROJECT/vpn/wireguard_normalidad" "$PROJECT/vpn/wireguard_pentesting" -type f ! -name '.gitkeep' -print -quit | grep -q .; then
  echo '[FAIL] Generated WireGuard state found in release archive.' >&2; exit 1
fi
if find "$PROJECT/mailserver1/data" "$PROJECT/mailserver1/state" "$PROJECT/mailserver2/data" "$PROJECT/mailserver2/state" -type f ! -name '.gitkeep' -print -quit | grep -q .; then
  echo '[FAIL] Persisted mail runtime state found in release archive.' >&2; exit 1
fi
if find "$PROJECT" -type f \( -name '*.pyc' -o -name '*.pyo' -o -name '.DS_Store' \) -print -quit | grep -q .; then
  echo '[FAIL] Generated development artefact found in release archive.' >&2; exit 1
fi

# Require isolated mitmproxy state and wg-easy v15 configuration.
normal_mount=$(grep -A25 '^[[:space:]]*reverse_proxy_normalidad:' "$PROJECT/compose.yml" | grep -F './mitmproxy/config/normalidad:/home/mitmproxy/.mitmproxy' || true)
pentest_mount=$(grep -A25 '^[[:space:]]*reverse_proxy_pentesting:' "$PROJECT/compose.yml" | grep -F './mitmproxy/config/pentesting:/home/mitmproxy/.mitmproxy' || true)
[[ -n "$normal_mount" && -n "$pentest_mount" ]] || { echo '[FAIL] Mitmproxy environments do not use isolated config mounts.' >&2; exit 1; }
if find "$PROJECT/vpn" -path '*/.env/*' -type f -print -quit | grep -q .; then
  echo '[FAIL] Residual VPN credential file found in release archive.' >&2; exit 1
fi
if grep -nE '(^|[[:space:]-])(WG_HOST|WG_DEVICE|PASSWORD_HASH)=' "$PROJECT/compose.yml"; then
  echo '[FAIL] Legacy wg-easy v14 environment variable found.' >&2; exit 1
fi

# Require isolated SMB mutable storage and reject obsolete components.
normal_smb_mount=$(grep -A25 '^[[:space:]]*smb_normalidad:' "$PROJECT/compose.yml" | grep -F './smb/share_normalidad:/share' || true)
pentest_smb_mount=$(grep -A25 '^[[:space:]]*smb_pentesting:' "$PROJECT/compose.yml" | grep -F './smb/share_pentesting:/share' || true)
[[ -n "$normal_smb_mount" && -n "$pentest_smb_mount" ]] || { echo '[FAIL] SMB environments do not use isolated share mounts.' >&2; exit 1; }
[[ -d "$PROJECT/smb/share_normalidad" && -d "$PROJECT/smb/share_pentesting" ]] || { echo '[FAIL] Isolated SMB share directories are missing.' >&2; exit 1; }
if [[ -e "$PROJECT/smb/share" ]]; then
  echo '[FAIL] Legacy shared SMB directory found in release archive.' >&2; exit 1
fi
if find "$PROJECT" \( -iname '*webcam*' -o -path "$PROJECT/media" -o -path "$PROJECT/media/*" \) -print -quit | grep -q .; then
  echo '[FAIL] Obsolete webcam/media artefact found in release archive.' >&2; exit 1
fi

# Require pinned images and paired services.
if grep -nE '^[[:space:]]*image:[[:space:]]*[^#[:space:]]+:latest([[:space:]]|$)' "$PROJECT/compose.yml"; then
  echo '[FAIL] Unpinned :latest image found in compose.yml.' >&2; exit 1
fi
for service in wg_collector_normalidad wg_collector_pentesting; do
  grep -q "^[[:space:]]*${service}:" "$PROJECT/compose.yml" || { echo "[FAIL] Missing service: ${service}" >&2; exit 1; }
done

# Require separate API/database secret sources and non-duplicated values.
for name in db_user db_password db_name secret_key; do
  grep -q "^[[:space:]]*${name}_normalidad:" "$PROJECT/compose.yml" || { echo "[FAIL] Missing ${name}_normalidad secret." >&2; exit 1; }
  grep -q "^[[:space:]]*${name}_pentesting:" "$PROJECT/compose.yml" || { echo "[FAIL] Missing ${name}_pentesting secret." >&2; exit 1; }
  n="$PROJECT/restful_api1/.env/${name}.txt"; p="$PROJECT/restful_api2/.env/${name}.txt"
  [[ -s "$n" && -s "$p" ]] || { echo "[FAIL] Missing ${name} secret file." >&2; exit 1; }
  cmp -s "$n" "$p" && { echo "[FAIL] Duplicated ${name} value across environments." >&2; exit 1; }
done

# Require credential documentation to match the deployed service configuration.
for item in \
  '`admin` | `password`' \
  '`ftpuser` | `password`' \
  '`root` | `password`' \
  '`smbuser` | `password`' \
  '`normal_user` | `normal_password`' \
  '`pentest_user` | `pentest_password`' \
  '`admin` | `normalidad-vpn`' \
  '`admin` | `pentesting-vpn`'; do
  grep -Fq "$item" CREDENTIALS.md || { echo "[FAIL] Missing credential documentation: $item" >&2; exit 1; }
done
grep -Fq 'SMB_USER: smbuser' "$PROJECT/compose.yml" || { echo '[FAIL] SMB username changed unexpectedly.' >&2; exit 1; }
grep -Fq 'SMB_PASSWORD: password' "$PROJECT/compose.yml" || { echo '[FAIL] SMB password changed unexpectedly.' >&2; exit 1; }
grep -Fq 'INIT_PASSWORD=normalidad-vpn' "$PROJECT/compose.yml" || { echo '[FAIL] WireGuard normalidad credential mismatch.' >&2; exit 1; }
grep -Fq 'INIT_PASSWORD=pentesting-vpn' "$PROJECT/compose.yml" || { echo '[FAIL] WireGuard pentesting credential mismatch.' >&2; exit 1; }

python3 -m py_compile "$PROJECT/wg-collector/collector.py"
bash -n "$PROJECT/smb-custom/entrypoint.sh" "$PROJECT/scripts/healthcheck.sh" "$PROJECT/scripts/validate_honeynet.sh"
python3 - <<'PY' "$PROJECT/compose.yml"
import sys, yaml
from pathlib import Path
with open(sys.argv[1], encoding='utf-8') as f:
    data=yaml.safe_load(f)
services = data.get('services')
assert isinstance(services, dict) and len(services) == 22, 'compose must define 22 services'
expected = {
    'wireguard_normalidad': {
        'password': 'normalidad-vpn', 'port': '51820',
        'udp_mapping': '51820:51820/udp', 'volume': './vpn/wireguard_normalidad:/etc/wireguard'
    },
    'wireguard_pentesting': {
        'password': 'pentesting-vpn', 'port': '51822',
        'udp_mapping': '51822:51822/udp', 'volume': './vpn/wireguard_pentesting:/etc/wireguard'
    },
}
for name, exp in expected.items():
    svc = services[name]
    assert svc.get('image') == 'ghcr.io/wg-easy/wg-easy:15.3.0', f'{name}: unexpected wg-easy image'
    env_raw = svc.get('environment', [])
    env = {}
    for item in env_raw:
        if isinstance(item, str) and '=' in item:
            k, v = item.split('=', 1); env[k] = v
        elif isinstance(item, dict):
            env.update({str(k): str(v) for k, v in item.items()})
    required = {
        'INSECURE': 'true', 'INIT_ENABLED': 'true', 'INIT_USERNAME': 'admin',
        'INIT_PASSWORD': exp['password'], 'INIT_HOST': '${HOST_IP}', 'INIT_PORT': exp['port']
    }
    assert all(env.get(k) == v for k, v in required.items()), f'{name}: invalid v15 initialization environment'
    assert not ({'WG_HOST','WG_DEVICE','PASSWORD_HASH'} & set(env)), f'{name}: legacy v14 variables present'
    ports = {str(x) for x in svc.get('ports', [])}
    assert exp['udp_mapping'] in ports, f'{name}: incorrect WireGuard UDP mapping'
    assert exp['volume'] in {str(x) for x in svc.get('volumes', [])}, f'{name}: missing isolated state mount'
    assert '/lib/modules:/lib/modules:ro' in {str(x) for x in svc.get('volumes', [])}, f'{name}: missing module mount'
    sysctls = {str(x) for x in svc.get('sysctls', [])}
    for value in ('net.ipv4.ip_forward=1','net.ipv4.conf.all.src_valid_mark=1'):
        assert value in sysctls, f'{name}: missing required sysctl {value}'
assert expected['wireguard_normalidad']['password'] != expected['wireguard_pentesting']['password']
PY
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  (cd "$PROJECT" && HOST_IP=127.0.0.1 docker compose config --quiet)
else
  echo '[WARN] Docker Compose unavailable; skipped Compose validation.'
fi
sha256sum -c SHA256SUMS
echo '[OK] Release validation completed.'
