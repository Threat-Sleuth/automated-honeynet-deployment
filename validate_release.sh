#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}"
cd "$ROOT"
required=(README.md RELEASE_NOTES.md CHANGELOG.md VERSION LICENSE CITATION.cff SECURITY.md CONTRIBUTING.md SERVICE_PORTS.txt honeynet.service honeynet.tar.gz install_honeynet.sh uninstall_honeynet.sh)
for f in "${required[@]}"; do [[ -s "$f" ]] || { echo "[FAIL] Missing or empty: $f" >&2; exit 1; }; done
bash -n install_honeynet.sh uninstall_honeynet.sh validate_release.sh

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

# Require isolated mitmproxy state and separate WireGuard UI credentials.
normal_mount=$(grep -A25 '^[[:space:]]*reverse_proxy_normalidad:' "$PROJECT/compose.yml" | grep -F './mitmproxy/config/normalidad:/home/mitmproxy/.mitmproxy' || true)
pentest_mount=$(grep -A25 '^[[:space:]]*reverse_proxy_pentesting:' "$PROJECT/compose.yml" | grep -F './mitmproxy/config/pentesting:/home/mitmproxy/.mitmproxy' || true)
[[ -n "$normal_mount" && -n "$pentest_mount" ]] || { echo '[FAIL] Mitmproxy environments do not use isolated config mounts.' >&2; exit 1; }
if find "$PROJECT/vpn" -path '*/.env/*' -type f -print -quit | grep -q .; then
  echo '[FAIL] Residual VPN credential file found in release archive.' >&2; exit 1
fi
mapfile -t wg_hashes < <(grep -E '^[[:space:]]*-[[:space:]]*PASSWORD_HASH=' "$PROJECT/compose.yml" | sed 's/.*PASSWORD_HASH=//')
[[ ${#wg_hashes[@]} -eq 2 ]] || { echo '[FAIL] Expected two WireGuard PASSWORD_HASH values.' >&2; exit 1; }
[[ "${wg_hashes[0]}" != "${wg_hashes[1]}" ]] || { echo '[FAIL] WireGuard UI password hashes are duplicated.' >&2; exit 1; }

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

python3 -m py_compile "$PROJECT/wg-collector/collector.py"
bash -n "$PROJECT/smb-custom/entrypoint.sh" "$PROJECT/scripts/healthcheck.sh" "$PROJECT/scripts/validate_honeynet.sh"
python3 - <<'PY' "$PROJECT/compose.yml"
import sys, yaml
with open(sys.argv[1], encoding='utf-8') as f:
    data=yaml.safe_load(f)
assert isinstance(data.get('services'), dict) and len(data['services']) == 22, 'compose must define 22 services'
PY
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  (cd "$PROJECT" && HOST_IP=127.0.0.1 docker compose config --quiet)
else
  echo '[WARN] Docker Compose unavailable; skipped Compose validation.'
fi
sha256sum -c SHA256SUMS
echo '[OK] Release validation completed.'
