#!/usr/bin/env bash
# remediate.sh : APPROVED, VERSION-CONTROLLED remediation RB-001 "Restart arc-demo-health".
# Constraints enforced here, not by the AI layer:
#   - requires an approval record (APPROVAL_ID) and the target name (REMEDIATION_TARGET)
#   - refuses to run on any host other than REMEDIATION_TARGET
#   - performs exactly one action: systemctl start arc-demo-health.service
#   - re-runs the SAME health test used for detection
# Exit codes: 0 recovered, 1 refused (missing approval / wrong host), 20 remediation did not restore health.
set -euo pipefail
RUNBOOK_ID="RB-001"
REMEDIATION_TARGET="${REMEDIATION_TARGET:-}"
APPROVAL_ID="${APPROVAL_ID:-}"
[[ -n "$REMEDIATION_TARGET" ]] || { echo "REFUSED: REMEDIATION_TARGET not set" >&2; exit 1; }
[[ -n "$APPROVAL_ID" ]]        || { echo "REFUSED: APPROVAL_ID not set (human approval required)" >&2; exit 1; }
# Identity check: accept the Arc resource name (what Azure calls this machine) or the OS hostname.
arc_name() { azcmagent show 2>/dev/null | awk -F': *' '/^Resource Name/{print $2; exit}'; }
me_is() { [[ "$(hostname)" == "$1" || "$(arc_name)" == "$1" ]]; }
me_is "$REMEDIATION_TARGET" || { echo "REFUSED: host $(hostname) (Arc: $(arc_name)) != approved target $REMEDIATION_TARGET" >&2; exit 1; }

here="$(cd "$(dirname "$0")" && pwd)"
echo "[$RUNBOOK_ID] approval=$APPROVAL_ID target=$REMEDIATION_TARGET"
echo "[$RUNBOOK_ID] pre-check:";  "$here/verify-health.sh" || true
echo "[$RUNBOOK_ID] action: systemctl start arc-demo-health.service"
sudo systemctl start arc-demo-health.service
sleep 2
logger -t arc-demo-health -p user.notice "service=arc-demo-health status=remediated host=$(hostname) runbook=$RUNBOOK_ID approval=$APPROVAL_ID"
echo "[$RUNBOOK_ID] post-check:"
if "$here/verify-health.sh"; then echo "[$RUNBOOK_ID] RESULT: recovered"; exit 0
else echo "[$RUNBOOK_ID] RESULT: NOT recovered. Rollback: none required (start is idempotent). Escalate." >&2; exit 20; fi
