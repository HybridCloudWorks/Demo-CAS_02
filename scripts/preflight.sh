#!/usr/bin/env bash
# preflight.sh : run INSIDE each Linux guest before onboarding.
# Checks OS, outbound HTTPS to Arc endpoints, DNS, time sync, demo service, and that this is not an Azure VM.
# Exit codes: 0 all pass, 1 one or more checks failed.
set -euo pipefail
fail=0
ok()   { printf '  [PASS] %s\n' "$1"; }
bad()  { printf '  [FAIL] %s\n' "$1"; fail=1; }
warn() { printf '  [WARN] %s\n' "$1"; }

echo "== Guest preflight on $(hostname) =="

. /etc/os-release
case "${ID}-${VERSION_ID}" in
  ubuntu-24.04|ubuntu-22.04) ok "OS ${PRETTY_NAME} (Arc-supported)";;
  *) warn "OS ${PRETTY_NAME}: confirm on the Arc supported-OS list";;
esac
[[ "$(uname -m)" == "x86_64" ]] && ok "Architecture x86_64" || warn "Architecture $(uname -m): only some Arc features on arm64"

for ep in login.microsoftonline.com management.azure.com gbl.his.arc.azure.com packages.microsoft.com agentserviceapi.guestconfiguration.azure.com; do
  if getent hosts "$ep" >/dev/null; then ok "DNS resolves $ep"; else bad "DNS cannot resolve $ep"; fi
done

for url in https://login.microsoftonline.com https://management.azure.com https://packages.microsoft.com; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$url" || echo 000)
  [[ "$code" != "000" ]] && ok "Outbound HTTPS to $url (HTTP $code)" || bad "No outbound HTTPS to $url"
done

if timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -q yes; then ok "Time synchronized"; else warn "Time not reported as synchronized"; fi

if curl -fsS --max-time 3 http://127.0.0.1:8080/health >/dev/null 2>&1; then ok "Demo service arc-demo-health healthy"; else bad "Demo service not healthy (run configure-demo-service.sh)"; fi

# Azure IMDS must NOT answer: Arc is for machines outside Azure.
if curl -s --max-time 2 -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | grep -q '"azEnvironment"'; then
  bad "Azure IMDS responded: this is an Azure VM. Do not Arc-enable it."
else ok "Not an Azure VM (Azure IMDS silent)"; fi

if command -v azcmagent >/dev/null; then
  ver=$(azcmagent version 2>/dev/null | head -1 || true); ok "azcmagent present: ${ver}"
else warn "azcmagent not installed yet (onboard-arc.sh installs it)"; fi

echo; [[ $fail -eq 0 ]] && { echo "PREFLIGHT PASS"; exit 0; } || { echo "PREFLIGHT FAIL" >&2; exit 1; }
