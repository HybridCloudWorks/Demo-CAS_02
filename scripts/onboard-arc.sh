#!/usr/bin/env bash
# onboard-arc.sh : install the Azure Connected Machine agent and connect this machine to Azure Arc.
# Auth: device code (default) or an existing az login (--use-azcli). No service principal secret.
#
# Required env vars (export before running; never put values in this file):
#   ARC_SUBSCRIPTION_ID ARC_TENANT_ID ARC_RESOURCE_GROUP ARC_LOCATION ARC_CLOUD_ORIGIN (Hyper-V|AWS|GCP)
# Optional: ARC_RESOURCE_NAME (default hostname), ARC_OWNER, ARC_COST_CENTER, ARC_EXPIRATION_DATE, ARC_AUTH (devicecode|azcli)
# Exit codes: 0 connected, 1 input error, 2 download/verify error, 3 install error, 4 connect error.
set -euo pipefail

for v in ARC_SUBSCRIPTION_ID ARC_TENANT_ID ARC_RESOURCE_GROUP ARC_LOCATION ARC_CLOUD_ORIGIN; do
  [[ -n "${!v:-}" ]] || { echo "ERROR: $v is not set" >&2; exit 1; }
done
case "$ARC_CLOUD_ORIGIN" in Hyper-V|AWS|GCP) ;; *) echo "ERROR: ARC_CLOUD_ORIGIN must be Hyper-V, AWS or GCP" >&2; exit 1;; esac
[[ $EUID -eq 0 ]] || { echo "ERROR: run as root (sudo -E)" >&2; exit 1; }

ARC_RESOURCE_NAME="${ARC_RESOURCE_NAME:-$(hostname)}"
ARC_AUTH="${ARC_AUTH:-devicecode}"
TAGS="Environment=Demo,Session=AzureArcHybrid,CloudOrigin=${ARC_CLOUD_ORIGIN},ManagedBy=AzureArc,Owner=${ARC_OWNER:-<OWNER>},CostCenter=${ARC_COST_CENTER:-<COST_CENTER>},ExpirationDate=${ARC_EXPIRATION_DATE:-<EXPIRATION_DATE>}"

# Refuse to onboard an Azure VM.
if curl -s --max-time 2 -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | grep -q '"azEnvironment"'; then
  echo "ERROR: Azure IMDS answered. This is an Azure VM; it already has native Azure management." >&2; exit 1
fi

if ! command -v azcmagent >/dev/null; then
  echo "Installing Azure Connected Machine agent..."
  # Install via Microsoft's package repository (integrity: Microsoft signing key + apt verification).
  # Exact repository path: verification required against current official documentation.
  . /etc/os-release
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  curl -fsSL -o "$tmp/packages-microsoft-prod.deb" \
    "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb" || { echo "ERROR: repo config download failed" >&2; exit 2; }
  dpkg -i "$tmp/packages-microsoft-prod.deb" >/dev/null || { echo "ERROR: repo config install failed" >&2; exit 3; }
  apt-get update -qq
  apt-get install -y -qq azcmagent || { echo "ERROR: azcmagent install failed" >&2; exit 3; }
fi
echo "Agent: $(azcmagent version | head -1)"

# Harden local agent surface (lab + production): no incoming connections, Machine Configuration on.
azcmagent config set incomingconnections.enabled false >/dev/null 2>&1 || true   # verification required
azcmagent config set guestconfiguration.enabled true   >/dev/null 2>&1 || true   # verification required

if azcmagent show 2>/dev/null | grep -Eqi 'Agent Status[[:space:]]*:[[:space:]]*Connected'; then
  echo "Already connected:"; azcmagent show | grep -Ei 'Resource Name|Resource Group|Agent Status'; exit 0
fi

echo "Connecting ${ARC_RESOURCE_NAME} (CloudOrigin=${ARC_CLOUD_ORIGIN}) to ${ARC_RESOURCE_GROUP} in ${ARC_LOCATION}..."
auth_args=(--use-device-code); [[ "$ARC_AUTH" == "azcli" ]] && auth_args=(--use-azcli)
azcmagent connect \
  --subscription-id "$ARC_SUBSCRIPTION_ID" \
  --tenant-id "$ARC_TENANT_ID" \
  --resource-group "$ARC_RESOURCE_GROUP" \
  --location "$ARC_LOCATION" \
  --resource-name "$ARC_RESOURCE_NAME" \
  --cloud AzureCloud \
  --tags "$TAGS" \
  --correlation-id "$(cat /proc/sys/kernel/random/uuid)" \
  "${auth_args[@]}" || { echo "ERROR: azcmagent connect failed (see /var/opt/azcmagent/log/himds.log)" >&2; exit 4; }

echo "Connected. Verify with: sudo azcmagent show"
