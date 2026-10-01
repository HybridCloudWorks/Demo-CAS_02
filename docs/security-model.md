# Security model

## Principles
1. **No secrets anywhere in the repo, slides, notes, screenshots, evidence or prompts.** Identity-based auth only: `az login`, device code in guests, AWS SSO profiles, Google ADC/OS Login, GitHub OIDC. `.gitignore` blocks tfvars, state, keys; `secret-scan.yml` runs gitleaks and a GUID/IP sanitization gate.
2. **Least privilege, scoped to the demo resource group / VPC / project.** No subscription-wide Owner or Contributor.
3. **The AI layer is read-only.** It receives a sanitized JSON package and returns text. It has no tools, no credentials, no network path to any machine.
4. **Humans approve; code executes.** The only execution path is `remediate.sh` at a pinned commit, invoked after a GitHub environment approval, scoped to one machine by workflow input *and* by a hostname guard inside the script.
5. **No inbound management ports by default.** SSM (AWS), IAP + OS Login (GCP), Hyper-V console (local). Public SSH is a labelled lab-only toggle restricted to a CIDR variable.

## Roles and identities
| Where | Identity | Role | Scope | Lifetime |
|---|---|---|---|---|
| Azure, instructor | User (az login) | Azure Connected Machine Onboarding; Reader; Log Analytics Reader; Resource Policy Contributor (for assignments) | `rg-arc-hybrid-demo` | Session; `az logout` after |
| Azure, workflow | App registration + federated credential (GitHub OIDC) | Azure Connected Machine Resource Administrator | `rg-arc-hybrid-demo` | Delete federated credential after event |
| Azure, policy DINE identities | System-assigned on assignments | **Lab-only shortcut:** Contributor on RG. Production: Log Analytics Contributor + Azure Connected Machine Resource Administrator + Monitoring Contributor | RG | Destroyed with RG |
| AWS | SSO profile (human) | PowerUser-equivalent in a sandbox account | Account | `aws sso logout` |
| AWS, instance | Instance role | AmazonSSMManagedInstanceCore | Instance | Destroyed by Terraform |
| GCP | ADC (human) | Compute Admin + Service Account User + IAP-secured Tunnel User in demo project | Project | `gcloud auth revoke` |
| GCP, VM | Service account | logging.logWriter, monitoring.metricWriter | Project | Destroyed by Terraform |
| GitHub | Reviewer | Required reviewer on `remediation-approval` (self-review disabled) | Repo | Remove after event |

Terraform runs locally with the human identity. Terraform does **not** create the Arc machine resources; `azcmagent connect` does, under the signed-in user.

## Agent hardening applied in `onboard-arc.sh`
`azcmagent config set incomingconnections.enabled false` (blocks SSH-over-Arc/WAC) and `guestconfiguration.enabled true`. Extension allowlists (`extensions.allowlist`) can restrict which extensions may run; for the demo, allow only `Microsoft.Azure.Monitor/AzureMonitorLinuxAgent` and `Microsoft.Azure.Extensions/CustomScript`. (Config keys: verification required against current official documentation.)

## Preflight security checks
- `git ls-files | xargs grep -lE 'AKIA|BEGIN .*PRIVATE|password='` returns nothing; gitleaks clean.
- `terraform plan` output contains no key material (none is generated).
- No SG/firewall rule with 0.0.0.0/0 on 22 unless `allow_public_ssh=true` and the slide says "Lab-only".
- Screenshots: tenant/subscription/project/account IDs and IPs redacted (`collect-evidence.sh` redacts GUIDs/IPs automatically).
- No stale tokens: `az account show`, `aws sts get-caller-identity`, `gcloud auth list` show only the expected identities.

## Credential revocation (after the event)
`az logout`; `aws sso logout`; `gcloud auth revoke --all` and `gcloud auth application-default revoke`; delete the GitHub federated credential and app registration (`az ad app federated-credential delete`, `az ad app delete`); remove GitHub environment reviewers/variables; delete Hyper-V checkpoints that contain a connected agent.

## Responsible AI review
Every model output is labelled AI-GENERATED; outputs must cite evidence paths; confidence and limitations are mandatory fields; refusals must include a safe next step; success is only declared by the deterministic verification query; the human approver and the pinned commit are recorded in the incident record for auditability.
