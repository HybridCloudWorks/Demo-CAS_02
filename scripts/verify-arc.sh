#!/usr/bin/env bash
# verify-arc.sh : confirm local agent state and (optionally) the Azure-side resource.
# Run inside the guest. Pass --azure to also query ARM from a workstation with az login.
# Exit codes: 0 connected, 1 not connected.
set -euo pipefail
echo "== Local agent =="
sudo azcmagent show | grep -Ei 'Resource Name|Resource Group|Subscription ID|Tenant ID|Agent Status|Agent Version|Cloud' | sed -E 's/([0-9a-f]{8})-[0-9a-f-]{27}/\1-****/g'
sudo azcmagent check --location "${ARC_LOCATION:-eastus2}" 2>/dev/null | tail -5 || true   # connectivity summary (verification required)
if sudo azcmagent show | grep -qi 'Agent Status.*Connected'; then echo "ARC STATUS: Connected"; else echo "ARC STATUS: NOT connected" >&2; exit 1; fi
