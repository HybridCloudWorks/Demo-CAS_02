#!/usr/bin/env bash
# verify-health.sh : THE health test. Used before the fault, to detect it, and to prove recovery.
# Emits one JSON line. Exit codes: 0 healthy, 10 unhealthy.
set -euo pipefail
host=$(hostname)
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
active=$(systemctl is-active arc-demo-health 2>/dev/null || true)
http=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 http://127.0.0.1:8080/health || echo 000)
if [[ "$active" == "active" && "$http" == "200" ]]; then status=healthy; rc=0; else status=unhealthy; rc=10; fi
printf '{"timestamp":"%s","host":"%s","service":"arc-demo-health","systemd":"%s","http":"%s","status":"%s"}\n' "$ts" "$host" "$active" "$http" "$status"
exit $rc
