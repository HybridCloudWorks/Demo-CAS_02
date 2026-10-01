#!/usr/bin/env bash
# collect-evidence.sh : build the CURATED, SANITIZED incident evidence package from a workstation (az login).
# Deterministic sources only: Azure Resource Graph (inventory, extensions, policy) + Log Analytics (health heartbeat).
# Output: evidence/incidents/<INCIDENT_ID>/evidence.json  (schema: evidence/incident-schema.json)
# Requires: az, jq, az extension resource-graph. Env: AZURE_RESOURCE_GROUP, LAW_CUSTOMER_ID (workspace GUID), INCIDENT_ID (optional)
set -euo pipefail
command -v az >/dev/null || { echo "ERROR: az not found" >&2; exit 1; }
command -v jq >/dev/null || { echo "ERROR: jq not found" >&2; exit 1; }
: "${AZURE_RESOURCE_GROUP:?set AZURE_RESOURCE_GROUP}"; : "${LAW_CUSTOMER_ID:?set LAW_CUSTOMER_ID}"
INCIDENT_ID="${INCIDENT_ID:-INC-$(date -u +%Y%m%d-%H%M)}"
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/evidence/incidents/$INCIDENT_ID"; mkdir -p "$out"
az extension show --name resource-graph >/dev/null 2>&1 || az extension add --name resource-graph --only-show-errors

redact() { sed -E 's/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/<REDACTED_GUID>/g; s/([0-9]{1,3}\.){3}[0-9]{1,3}/<REDACTED_IP>/g'; }

q_inv=$(sed "s/<AZURE_RESOURCE_GROUP>/$AZURE_RESOURCE_GROUP/" "$root/queries/arc-inventory.kql")
q_ext=$(sed "s/<AZURE_RESOURCE_GROUP>/$AZURE_RESOURCE_GROUP/" "$root/queries/extension-inventory.kql")
q_pol=$(sed "s/<AZURE_RESOURCE_GROUP>/$AZURE_RESOURCE_GROUP/" "$root/queries/policy-state.kql")

inventory=$(az graph query -q "$q_inv" --first 50 -o json | jq '.data')
extensions=$(az graph query -q "$q_ext" --first 100 -o json | jq '.data')
policy=$(az graph query -q "$q_pol" --first 100 -o json | jq '.data' 2>/dev/null || echo '[]')
health=$(az monitor log-analytics query -w "$LAW_CUSTOMER_ID" --analytics-query "$(cat "$root/queries/arc-health.kql")" -o json 2>/dev/null || echo '[]')

jq -n --arg id "$INCIDENT_ID" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --argjson inv "$inventory" --argjson ext "$extensions" --argjson pol "$policy" --argjson hb "$health" '
{
  incident_id: $id, collected_at: $ts, collector: "collect-evidence.sh", schema_version: "1.0",
  sources: [
    {name:"azure_resource_graph", query:"queries/arc-inventory.kql"},
    {name:"azure_resource_graph", query:"queries/extension-inventory.kql"},
    {name:"azure_resource_graph", query:"queries/policy-state.kql"},
    {name:"log_analytics",        query:"queries/arc-health.kql"}
  ],
  inventory: $inv, extensions: $ext, policy_state: $pol, health: $hb,
  approved_runbooks: [{id:"RB-001", title:"Restart arc-demo-health", path:"scripts/remediate.sh", scope:"single named machine", requires_approval:true}],
  redaction: "GUIDs and IPs replaced before storage"
}' | redact > "$out/evidence.json"

echo "Evidence written: $out/evidence.json"
jq -r '.health[]? | "\(.Computer)  \(.status)  \(.LastSeen)"' "$out/evidence.json" || true
grep -Eq 'password|secret|AKIA|BEGIN (RSA|OPENSSH) PRIVATE' "$out/evidence.json" && { echo "ERROR: possible secret in evidence" >&2; exit 2; } || echo "Secret scan: clean"
