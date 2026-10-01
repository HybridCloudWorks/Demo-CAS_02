# Evidence

Curated, sanitized incident evidence produced by `scripts/collect-evidence.sh` and consumed by the AI explanation layer (`ai/`).

* `incident-schema.json` – JSON Schema (draft 2020-12) for an evidence package and its incident record.
* `sanitized-example.json` – a complete example from the Hyper-V fault scenario, with GUIDs and IPs redacted.
* `incidents/<INCIDENT_ID>/` – generated at runtime (git-ignored except the sanitized example).

Rules: no credentials, tenant/subscription/project/account IDs, or public IPs. `collect-evidence.sh` redacts GUIDs and IPv4 addresses and fails if it detects secret-like strings. Tags such as `CloudOrigin` are claims written at onboarding time, not cryptographic proof of hosting origin; the AI layer must say so when asked.
