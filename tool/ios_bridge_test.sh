#!/usr/bin/env bash
# Checks the iOS bridge end to end on a simulator. Dart calls
# DiditSdk.startVerificationWithWorkflow (example/integration_test/
# retry_blocked_test.dart), the plugin starts the pinned native SDK, and the
# native SDK sends its session request to tool/stand_in_api.py, which answers
# the way the verification API answers a person with no retries left. The
# native SDK then ends the flow through its own callback, and the test checks
# the result Dart receives.
#
# macOS with Xcode and Flutter, Swift Package Manager disabled
# (`flutter config --no-enable-swift-package-manager`, as in the iOS CI job).
# It uses sudo to point the API host at this machine in /etc/hosts and restores
# the file on exit. The simulator keeps trusting the throwaway certificate
# authority, whose private key is deleted on exit.
#
# Usage: tool/ios_bridge_test.sh [simulator udid]  (default: the first available iPhone)
set -euo pipefail

cd "$(dirname "$0")/.."

api_host=verification.didit.me
udid=${1:-$(xcrun simctl list devices available --json | python3 -c 'import json, sys; print(next(d["udid"] for runtime, devices in json.load(sys.stdin)["devices"].items() if "iOS" in runtime for d in devices if d["name"].startswith("iPhone")))')}
work=$(mktemp -d)

flush_dns() {
  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder || true
}

cleanup() {
  if [[ -n "${server_pid:-}" ]]; then kill "$server_pid" 2>/dev/null || true; fi
  if [[ -f "$work/hosts" ]]; then
    sudo cp "$work/hosts" /etc/hosts
    flush_dns
  fi
  if [[ -f "$work/server.log" ]]; then
    echo "Requests the stand-in API received:"
    cat "$work/server.log"
  fi
  rm -rf "$work"
}
trap cleanup EXIT

# A certificate authority the simulator trusts, and a certificate for the API
# host that meets iOS's rules for TLS server certificates.
cat > "$work/ca.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ca
prompt = no
[dn]
CN = Didit SDK bridge test CA
[ca]
basicConstraints = critical, CA:true
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
EOF
cat > "$work/server.ext" <<EOF
basicConstraints = CA:false
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = DNS:$api_host
EOF
openssl req -x509 -new -newkey rsa:2048 -nodes -sha256 -days 2 -config "$work/ca.cnf" \
  -keyout "$work/ca.key" -out "$work/ca.pem" 2>/dev/null
openssl req -new -newkey rsa:2048 -nodes -sha256 -subj "/CN=$api_host" \
  -keyout "$work/server.key" -out "$work/server.csr" 2>/dev/null
openssl x509 -req -sha256 -days 2 -in "$work/server.csr" -CA "$work/ca.pem" -CAkey "$work/ca.key" \
  -CAcreateserial -extfile "$work/server.ext" -out "$work/server.pem" 2>/dev/null

cp /etc/hosts "$work/hosts"
printf '127.0.0.1 %s\n::1 %s\n' "$api_host" "$api_host" | sudo tee -a /etc/hosts > /dev/null
flush_dns

python3 tool/stand_in_api.py --cert "$work/server.pem" --key "$work/server.key" 2> "$work/server.log" &
server_pid=$!

# The host itself must reach the stand-in through the API host name before the
# simulator tries.
for _ in $(seq 50); do
  if curl --silent --fail --cacert "$work/ca.pem" --request POST --data '{}' \
    "https://$api_host/v1/session/unilink/bridge-check/" > "$work/answer.json"; then
    break
  fi
  sleep 0.2
done
grep -q '"can_retry": false' "$work/answer.json" || {
  echo "The stand-in API does not answer on https://$api_host" >&2
  exit 1
}

# Boot after the hosts change, then trust the certificate authority.
xcrun simctl shutdown "$udid" 2> /dev/null || true
xcrun simctl bootstatus "$udid" -b
xcrun simctl keychain "$udid" add-root-cert "$work/ca.pem"

(cd example && flutter test integration_test/retry_blocked_test.dart -d "$udid" \
  --dart-define=DIDIT_STAND_IN_API=true)
