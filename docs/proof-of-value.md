# 30-day proof of value (customer proposal)

**Scope (small and explicit):** 5–10 servers: at least one on-premises/private (Hyper-V, VMware, physical) and at least one in a non-Azure cloud (AWS or GCP). Non-production or low-risk production only. No Azure VMs (they are already natively managed).

| Week | Activity | Gate to proceed |
|---|---|---|
| 1 | Prerequisites, network allow-list, onboarding identity (Onboarding role at RG scope), onboard with the Connected Machine agent, apply naming/tags, **read-only inventory** via Resource Graph | All servers Connected; tags validated against detected cloud |
| 2 | **Policy assessment only** (Linux/Windows baseline audit, required tags), AMA + DCR for one health signal, Log Analytics workbook | Compliance report reviewed; no enforcement yet |
| 3 | **Limited approved remediation**: one runbook (e.g., restart a named service / fix one baseline setting) behind a GitHub/Azure DevOps approval environment; AI explanation layer in advisory mode with the evaluation set (≥ 19/20, zero unsafe) | Security review sign-off on approval trail, OIDC, RBAC |
| 4 | Operate: run the lifecycle on 2–3 real low-risk incidents; measure; decide | Success metrics met; exit criteria evaluated |

**Human approval** is mandatory for every change; no organization-wide autonomous remediation.

**Success metrics:** inventory coverage 100 % of scoped servers; time-to-evidence < 5 min; time-to-approved-fix < 30 min; 0 unapproved changes; 0 secrets in repo/evidence; policy compliance baseline captured; monthly cost within budget (Machine Configuration $6/server/month + logs).

**Security review:** least-privilege roles, agent hardening (incoming connections off, extension allowlist), Private Link or Arc gateway if required, approval protection rules, audit of all executions.

**Cost tracking:** tags/labels + budgets as in docs/cost-management.md.

**Exit criteria:** metrics met → expand scope gradually (next 25 servers) with the same gates; metrics missed → keep read-only inventory and policy audit (still valuable) and revisit remediation.

**Rollback plan:** `azcmagent disconnect` removes Azure resources without touching workloads; remove policy assignments; destroy workspace/DCR; revoke roles and federated credentials. Servers keep running exactly as before.
