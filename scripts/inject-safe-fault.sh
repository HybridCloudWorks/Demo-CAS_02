#!/usr/bin/env bash
# inject-safe-fault.sh : stop ONLY the demo service on ONLY the approved target (default arc-hyperv-demo).
# Safe: no OS service, security control, or data is touched. Reversible with remediate.sh.
# Exit codes: 0 fault injected, 1 refused (wrong host), 2 service missing.
set -euo pipefail
TARGET="${FAULT_TARGET:-arc-hyperv-demo}"
if [[ "$(hostname)" != "$TARGET" ]]; then
  echo "REFUSED: this host is $(hostname); fault target is $TARGET." >&2; exit 1
fi
systemctl list-unit-files arc-demo-health.service >/dev/null 2>&1 || { echo "ERROR: demo service not installed" >&2; exit 2; }
echo "Before:"; "$(dirname "$0")/verify-health.sh" || true
sudo systemctl stop arc-demo-health.service
logger -t arc-demo-health -p user.warning "service=arc-demo-health status=unhealthy host=$(hostname) reason=lab_fault_injected"
echo "After:"; "$(dirname "$0")/verify-health.sh" || true
echo "Fault injected on $TARGET. AWS and GCP untouched."
