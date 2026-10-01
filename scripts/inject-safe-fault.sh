#!/usr/bin/env bash
# inject-safe-fault.sh : stop ONLY the demo service on ONLY the approved target (default arc-aws-demo; override with FAULT_TARGET).
# Safe: no OS service, security control, or data is touched. Reversible with remediate.sh.
# Exit codes: 0 fault injected, 1 refused (wrong host), 2 service missing.
set -euo pipefail
# Identity check: accept the Arc resource name (what Azure calls this machine) or the OS hostname.
arc_name() { azcmagent show 2>/dev/null | awk -F': *' '/^Resource Name/{print $2; exit}'; }
me_is() { [[ "$(hostname)" == "$1" || "$(arc_name)" == "$1" ]]; }
TARGET="${FAULT_TARGET:-arc-aws-demo}"
if ! me_is "$TARGET"; then
  echo "REFUSED: this host is $(hostname) (Arc: $(arc_name)); fault target is $TARGET." >&2; exit 1
fi
systemctl list-unit-files arc-demo-health.service >/dev/null 2>&1 || { echo "ERROR: demo service not installed" >&2; exit 2; }
echo "Before:"; "$(dirname "$0")/verify-health.sh" || true
sudo systemctl stop arc-demo-health.service
logger -t arc-demo-health -p user.warning "service=arc-demo-health status=unhealthy host=$(hostname) reason=lab_fault_injected"
echo "After:"; "$(dirname "$0")/verify-health.sh" || true
echo "Fault injected on $TARGET. Every other machine untouched."
