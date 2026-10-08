# Azure Arc: one control plane for AWS, Google Cloud and private infrastructure

Session repository for the Cloud & AI Summit 2026 two-hour instructor-led session **"One control plane. Three hosting locations."** — a single hybrid incident lifecycle, **Detect → Explain → Approve → Remediate → Verify → Document**, across Ubuntu servers in three hosting locations (the live fault runs on `arc-aws-demo`; Hyper-V is an optional path kept under `powershell/`):

| Machine | Where it runs | How it is built | How it is managed |
|---|---|---|---|
| `arcs-lab-hybrid-prod-cus-01` | Private lab (KVM host, pre-existing) | Already connected; read-only in the session | Azure Arc |
| `arc-aws-demo` | Amazon EC2 | Terraform (`terraform/aws`) | Azure Arc |
| `arc-gcp-demo` | Google Compute Engine | Terraform (`terraform/gcp`) | Azure Arc |

Arc gives each server an Azure resource identity so tags, Resource Graph, Policy, Azure Monitor and the extension framework work the same way for all three. The servers never leave their hosts; AWS and Google Cloud keep their native control planes; an ordinary Azure VM is not Arc-enabled because it already has native management.

## Start here
1. `docs/instructor-runbook.md` — 28 steps with commands, expected output, narration, failure modes and backup switch points.
2. `docs/attendee-lab.md` — reusable lab with cost warnings and knowledge checks.
3. `slides/AzureArc-HybridIncident-CAS2026.pptx` — the summit deck; `slides/slide-outline.md` and `slides/presenter-notes.md` carry the full specification and talk track.
4. `docs/demo-fallback.md` + `backup/` — the read-only **Hybrid Estate Briefing**.

## Repository layout
```
README.md  Publish-Repo.ps1  .gitignore  .env.example
Deploy-Demo.ps1 · Setup-ApprovalGate.ps1 · Cleanup-Demo.ps1   instructor helpers; copy demo-settings.example.psd1 to demo-settings.psd1 (git-ignored) first
docs/      architecture · onboarding-decision-matrix · instructor-runbook · attendee-lab · security-model
           troubleshooting · demo-fallback · cleanup · cost-management · proof-of-value · acceptance-tests · preflight-checklist
slides/    AzureArc-HybridIncident-CAS2026.pptx · slide-outline.md · presenter-notes.md · architecture.png
terraform/ aws/ gcp/ azure/  (versions, providers, variables, main, outputs, terraform.tfvars.example)
powershell/ Test-HyperVPrerequisites · New-ArcHyperVVM · Get-ArcHyperVVMStatus · Remove-ArcHyperVVM · Remove-AllDemoResources
scripts/   cloud-init.yaml · preflight · configure-demo-service · onboard-arc · verify-arc · verify-health
           inject-safe-fault · collect-evidence · remediate (RB-001) · cleanup
queries/   arc-inventory · arc-health · policy-state · extension-inventory · resource-graph-query (.kql)
evidence/  README · incident-schema.json · sanitized-example.json
ai/        system-prompt.md · explain-incident.sh · evaluation-set.json
backup/    captured, sanitized artifacts for the fallback demo
.github/workflows/ remediate.yml (approval-gated RB-001) · secret-scan.yml
```
Deviations from the requested structure: `ai/` holds the model prompt, evaluation set and call script (the AI layer is a separate trust boundary); `backup/` holds captured artifacts; `.github/workflows/` is where the approval gate lives; `scripts/cloud-init.yaml` is shared by all three platforms; `powershell/Remove-AllDemoResources.ps1` and `Publish-Repo.ps1` were added at the instructor's request.

## Quick commands
```
# Azure prerequisites            cd terraform/azure && terraform init && terraform apply
# Hyper-V VM (optional)          powershell/New-ArcHyperVVM.ps1 -SwitchName 'Default Switch' -IsoPath <LINUX_IMAGE_PATH> -VmPath <HYPERV_VM_PATH>
# AWS / GCP VMs                  cd terraform/aws && terraform apply ; cd terraform/gcp && terraform apply
# Onboard (in each guest)        sudo -E bash scripts/onboard-arc.sh
# Health (same query always)     az monitor log-analytics query -w $LAW_CUSTOMER_ID --analytics-query "$(cat queries/arc-health.kql)" -o table
# Destroy everything             pwsh powershell/Remove-AllDemoResources.ps1 -ResourceGroup ... -AwsRegion ... -GcpProject ...
```

## Status labels used throughout
**GA** — verified supported. **Preview** — multicloud connector for GCP, Arc Run Command, agent automatic upgrade, Foundry hosted agents; never the only live path. **Lab-only shortcut. Not recommended for production.** — labelled wherever used, with the production alternative. **Verification required against current official documentation** — exact CLI/Terraform argument names that were not confirmed against an official page at authoring time (October 2026). Nothing in this repository is claimed to have been executed; run the acceptance tests in `docs/acceptance-tests.md` during rehearsal.

## Security
No secrets, IDs or IPs are stored here. Identity-based authentication everywhere; least privilege at resource-group / VPC / project scope; AI layer is read-only; humans approve; a pinned script executes on one named machine. See `docs/security-model.md`.
