# Preflight checklist (T-24h and T-60min)

## Workstation and Hyper-V (`powershell/Test-HyperVPrerequisites.ps1`) — Hyper-V items OPTIONAL, not used in the CAS 2026 delivery
- [ ] Windows 11 Pro/Enterprise/Education or Windows Server (not Home)
- [ ] Hyper-V feature Enabled; Hyper-V PowerShell module present
- [ ] Elevated PowerShell; hardware virtualization/SLAT available or hypervisor already running
- [ ] ≥ 6 GB free RAM, ≥ 45 GB free disk on the VM volume
- [ ] Virtual switch `<HYPERV_SWITCH_NAME>` exists (Default Switch = NAT + DHCP + DNS)
- [ ] Ubuntu Server 24.04 ISO present and SHA256 verified (Path A) or VHDX + cidata ISO (Path B)
- [ ] PowerShell 5.1+ / 7.x; DNS and TCP 443 to Arc endpoints

## Local tools
- [ ] git, terraform (≥ 1.9), az, aws (v2), gcloud, PowerShell, ssh, jq (or `python3 -m json.tool`)
- [ ] `terraform init` succeeded in aws/gcp/azure with providers aws ~> 6.0, google ~> 8.0, azurerm ~> 5.0
- [ ] `az extension add --name resource-graph`, `--name connectedmachine`

## Cloud authentication (no secrets on disk beyond tool caches)
- [ ] `aws sts get-caller-identity` shows the demo account; `AWS_REGION` set
- [ ] `gcloud auth list` + `gcloud config get-value project` = demo project; ADC valid
- [ ] `az account show` = demo subscription and tenant; user has Onboarding + Reader roles on the RG

## Azure Arc
- [ ] Providers registered: HybridCompute, GuestConfiguration, HybridConnectivity
- [ ] RG exists with tags; LAW + DCR deployed; policy assignments present
- [ ] `scripts/preflight.sh` PASS in each guest (endpoints, DNS, not-Azure, service healthy)
- [ ] `azcmagent version` ≥ 1.6x on both cloud machines; `azcmagent show` → Connected ×2

## Demo workflow
- [ ] `queries/arc-health.kql` → healthy ×2; `arc-inventory.kql` → 2 demo rows plus any pre-existing Arc servers
- [ ] Resource Graph, Policy, Log Analytics access verified from the workstation
- [ ] `ai/explain-incident.sh` returns a grounded answer on `evidence/sanitized-example.json`
- [ ] GitHub environment `remediation-approval` has a reviewer who is not the presenter's dispatch account
- [ ] `sha256sum scripts/remediate.sh` recorded; commit SHA pinned in notes
- [ ] `backup/` folder opens; `docs/demo-fallback.md` bookmarked

## Security
- [ ] `git status` clean; gitleaks clean; no `*.tfvars` tracked
- [ ] `terraform plan` shows no key material; `allow_public_ssh` state known and labelled
- [ ] Screenshots redacted; browser profile for demo has no other tenants visible
- [ ] `aws sts`, `gcloud auth list`, `az account list` show no stale extra identities
