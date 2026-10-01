# Instructor runbook

Numbered steps map to the live demonstration order. Time boxes: steps 1–14 are completed **before** the session (rehearsal + T-60 min reset); steps 15–23 run live between 1:15 and 1:45; steps 24–28 run immediately after Q&A.

Each step: **Objective · Environment · Command · Expected output · What the instructor says · What the audience should notice · What can fail · Recovery · Verification · Switch-to-backup point.**

## 1. Workstation and Hyper-V preparation

- **Environment:** Instructor laptop (Windows 11)
- **Command:**
```
cd powershell; .\Test-HyperVPrerequisites.ps1 -SwitchName '<HYPERV_SWITCH_NAME>' -MediaPath '<LINUX_IMAGE_PATH>' -VmPath '<HYPERV_VM_PATH>'
```
- **Expected output:** PREFLIGHT PASS, exit 0
- **Instructor says:** "Everything local starts with a boring checklist; the boring checklist is why the demo works."
- **Audience should notice:** Every dependency is checked before anything is built.
- **What can fail:** Hyper-V disabled, Home edition, no switch, no 443.
- **Recovery action:** Fix per docs/troubleshooting.md; if Hyper-V cannot be fixed, present Hyper-V from the backup clip.
- **Verification command:** `Same script; exit 0`
- **Switch to backup:** Do not switch yet; this is T-24h.

## 2. Secure local credential setup

- **Environment:** Workstation
- **Command:**
```
cp .env.example .env; edit placeholders; source .env; az login --use-device-code; aws sso login --profile $AWS_PROFILE; gcloud auth login; gcloud auth application-default login
```
- **Expected output:** Three identities signed in; no secret files created
- **Instructor says:** "No keys, no secrets files: three interactive logins and short-lived tokens in tool caches only."
- **Audience should notice:** Identity-based auth across three clouds.
- **What can fail:** Wrong tenant/account/project selected.
- **Recovery action:** az account set --subscription; aws configure sso; gcloud config set project.
- **Verification command:** `az account show; aws sts get-caller-identity; gcloud auth list`
- **Switch to backup:** If any auth is broken at T-60min, use the backup for that cloud.

## 3. Azure prerequisite validation

- **Environment:** Workstation
- **Command:**
```
az provider show -n Microsoft.HybridCompute --query registrationState; az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv) -g $AZURE_RESOURCE_GROUP -o table
```
- **Expected output:** Registered; Onboarding + Reader roles listed
- **Instructor says:** "Arc needs three resource providers and one small role at resource-group scope. No subscription Owner."
- **Audience should notice:** Least privilege at RG scope.
- **What can fail:** Provider NotRegistered; role missing.
- **Recovery action:** az provider register -n Microsoft.HybridCompute (and GuestConfiguration, HybridConnectivity); request role.
- **Verification command:** `Repeat commands`
- **Switch to backup:** N/A

## 4. Terraform initialization and validation

- **Environment:** Workstation
- **Command:**
```
for d in aws gcp azure; do (cd terraform/$d && cp -n terraform.tfvars.example terraform.tfvars && terraform init -input=false && terraform fmt -check && terraform validate && terraform plan -out=tfplan); done
```
- **Expected output:** Success! The configuration is valid; plans list ~10 (aws), ~12 (gcp), ~12 (azure) resources
- **Instructor says:** "Providers pinned: aws 6, google 8, azurerm 5. tfvars are git-ignored and placeholder-only in the repo."
- **Audience should notice:** No credentials in any .tf file.
- **What can fail:** Provider download blocked; tfvars placeholders not replaced.
- **Recovery action:** Replace placeholders; check proxy; use `terraform providers lock`.
- **Verification command:** `terraform validate`
- **Switch to backup:** N/A

## 5. Hyper-V VM creation

- **Environment:** Instructor laptop
- **Command:**
```
.\New-ArcHyperVVM.ps1 -SwitchName '<HYPERV_SWITCH_NAME>' -IsoPath '<LINUX_IMAGE_PATH>' -VmPath '<HYPERV_VM_PATH>'  # Path A
# Path B: -UseBaseVhdx -BaseVhdxPath <VHDX> -CidataIsoPath <CIDATA_ISO>
```
- **Expected output:** VM arc-hyperv-demo created and started; Gen 2; Secure Boot MicrosoftUEFICertificateAuthority
- **Instructor says:** "This VM is the machine outside Azure. It will stay on this laptop for the whole session."
- **Audience should notice:** Generation 2, Secure Boot with the Linux CA template, dynamic memory, no automatic checkpoints.
- **What can fail:** Secure Boot template wrong; ISO path wrong; not enough RAM.
- **Recovery action:** Fix firmware template; lower memory; see troubleshooting.
- **Verification command:** `.\Get-ArcHyperVVMStatus.ps1 -WaitForIpSeconds 120`
- **Switch to backup:** If the VM cannot boot at T-60min, present Hyper-V via the pre-onboarded checkpoint or backup.

## 6. AWS VM creation

- **Environment:** Workstation
- **Command:**
```
cd terraform/aws && terraform apply tfplan && terraform output
```
- **Expected output:** Apply complete; outputs instance_id, ssm_session_command (public_ip is sensitive)
- **Instructor says:** "One t3.micro in a dedicated VPC, egress-only security group, SSM instance profile, IMDSv2. No inbound SSH by default."
- **Audience should notice:** No public management port; identity via instance role.
- **What can fail:** Quota, Canonical AMI lookup, region mismatch.
- **Recovery action:** Troubleshooting: AWS section.
- **Verification command:** `aws ssm describe-instance-information --query 'InstanceInformationList[].PingStatus'`
- **Switch to backup:** If apply fails, AWS column comes from backup; demo still works (fault is on Hyper-V).

## 7. Google Cloud VM creation

- **Environment:** Workstation
- **Command:**
```
cd terraform/gcp && terraform apply tfplan && terraform output
```
- **Expected output:** Apply complete; outputs instance_name, iap_ssh_command
- **Instructor says:** "One e2-micro, OS Login, IAP-only SSH firewall, least-privilege service account, Shielded VM."
- **Audience should notice:** Labels are lowercase (GCP constraint); Azure tags will be set at onboarding.
- **What can fail:** API not enabled; zone capacity.
- **Recovery action:** Re-apply after API enable; change zone.
- **Verification command:** `gcloud compute instances describe arc-gcp-demo --zone $GCP_ZONE --format='value(status)'`
- **Switch to backup:** Same as AWS: backup column.

## 8. Linux guest configuration

- **Environment:** Each guest (console, SSM, IAP)
- **Command:**
```
sudo cloud-init status --wait   # AWS/GCP/Path B
# Path A only: sudo bash scripts/configure-demo-service.sh
```
- **Expected output:** status: done; service responds on 127.0.0.1:8080/health
- **Instructor says:** "Identical guest configuration everywhere, delivered by cloud-init; the Arc agent is deliberately not part of it."
- **Audience should notice:** Same cloud-init on three platforms.
- **What can fail:** cloud-init errors; python3 missing.
- **Recovery action:** sudo cloud-init collect-logs; run configure-demo-service.sh.
- **Verification command:** `curl -s http://127.0.0.1:8080/health`
- **Switch to backup:** N/A

## 9. Demo service installation

- **Environment:** Each guest
- **Command:**
```
sudo systemctl status arc-demo-health arc-demo-heartbeat.timer --no-pager
```
- **Expected output:** active (running); timer active
- **Instructor says:** "A harmless service: no data, no dependency, safe to stop, deterministic to start."
- **Audience should notice:** Heartbeat writes one syslog line per minute.
- **What can fail:** Unit failed.
- **Recovery action:** journalctl -u arc-demo-health; re-run configure-demo-service.sh.
- **Verification command:** `bash scripts/verify-health.sh → status healthy, exit 0`
- **Switch to backup:** N/A

## 10. Azure Arc onboarding

- **Environment:** Each guest
- **Command:**
```
export ARC_SUBSCRIPTION_ID=... ARC_TENANT_ID=... ARC_RESOURCE_GROUP=... ARC_LOCATION=... ARC_CLOUD_ORIGIN=Hyper-V|AWS|GCP ARC_RESOURCE_NAME=$(hostname)
sudo -E bash scripts/onboard-arc.sh
```
- **Expected output:** Device code shown → sign in within 5 min → 'Connected.'
- **Instructor says:** "Watch: the machine signs in with my identity, no stored secret, and becomes an Azure resource while staying exactly where it is."
- **Audience should notice:** The `--tags` set CloudOrigin per machine; the agent refuses on Azure VMs.
- **What can fail:** AuthorizationFailed; endpoint blocked; device code expired.
- **Recovery action:** Grant Onboarding role; fix 443; re-run (idempotent).
- **Verification command:** `sudo azcmagent show | grep 'Agent Status'`
- **Switch to backup:** Live onboarding of ONE machine (Hyper-V) is optional in the session; AWS/GCP are pre-onboarded. If it fails, show the pre-onboarded ones.

## 11. Connection-state verification

- **Environment:** Workstation
- **Command:**
```
az graph query -q "$(sed s/'<AZURE_RESOURCE_GROUP>'/$AZURE_RESOURCE_GROUP/ queries/arc-inventory.kql)" -o table
```
- **Expected output:** 3 rows, status Connected
- **Instructor says:** "One query, three hosting locations, one answer."
- **Audience should notice:** Resource type microsoft.hybridcompute/machines.
- **What can fail:** Only 2 rows (one machine not connected).
- **Recovery action:** verify-arc.sh on the missing guest.
- **Verification command:** `Same query`
- **Switch to backup:** Use backup/01-inventory.json if query access fails.

## 12. CloudOrigin tag verification

- **Environment:** Workstation
- **Command:**
```
az graph query -q "$(sed s/'<AZURE_RESOURCE_GROUP>'/$AZURE_RESOURCE_GROUP/ queries/resource-graph-query.kql | sed -n '1,9p')" -o table
```
- **Expected output:** Hyper-V 1, AWS 1, GCP 1
- **Instructor says:** "Tags say where each machine lives. The agent's detected cloud confirms AWS and GCP; Hyper-V shows N/A. Tags are claims; validate them."
- **Audience should notice:** Tag vs detected-cloud consistency.
- **What can fail:** Untagged machine.
- **Recovery action:** az tag update --operation merge.
- **Verification command:** `Section 3 of resource-graph-query.kql returns 0 rows`
- **Switch to backup:** N/A

## 13. Policy and extension verification

- **Environment:** Workstation
- **Command:**
```
az graph query -q "$(sed s/'<AZURE_RESOURCE_GROUP>'/$AZURE_RESOURCE_GROUP/ queries/extension-inventory.kql)" -o table
az graph query -q "$(sed s/'<AZURE_RESOURCE_GROUP>'/$AZURE_RESOURCE_GROUP/ queries/policy-state.kql)" -o table
```
- **Expected output:** AzureMonitorLinuxAgent Succeeded ×3; baseline audit Compliant/NonCompliant per machine
- **Instructor says:** "Policy installed the monitoring agent on all three via DeployIfNotExists, including the one on my laptop."
- **Audience should notice:** Governance applied uniformly to non-Azure machines.
- **What can fail:** Extension still provisioning (policy DINE up to ~30 min).
- **Recovery action:** Pre-stage the day before; or `az connectedmachine extension create` manually.
- **Verification command:** `Extension query`
- **Switch to backup:** Use backup/03 and /04.

## 14. Health verification across all three

- **Environment:** Workstation
- **Command:**
```
az monitor log-analytics query -w $LAW_CUSTOMER_ID --analytics-query "$(cat queries/arc-health.kql)" -o table
```
- **Expected output:** healthy ×3 with LastSeen within 2 min
- **Instructor says:** "This is THE health test. We will run this exact query again after the fault and again after the fix."
- **Audience should notice:** Same query = same truth.
- **What can fail:** No rows (ingestion lag).
- **Recovery action:** Wait 2–5 min; show verify-health.sh locally meanwhile.
- **Verification command:** `Same query`
- **Switch to backup:** Backup/02 if Log Analytics unavailable.

## 15. Safe fault injection on arc-hyperv-demo

- **Environment:** Hyper-V guest console
- **Command:**
```
bash scripts/inject-safe-fault.sh
```
- **Expected output:** Before: healthy; After: unhealthy; 'Fault injected on arc-hyperv-demo. AWS and GCP untouched.'
- **Instructor says:** "I am stopping one harmless service on the local machine only. Nothing in AWS or Google Cloud changes."
- **Audience should notice:** The script refuses to run on any other host.
- **What can fail:** Script run on wrong host → REFUSED (good).
- **Recovery action:** Run on the Hyper-V guest.
- **Verification command:** `bash scripts/verify-health.sh → exit 10`
- **Switch to backup:** Backup from here if the VM is unreachable.

## 16. Evidence collection

- **Environment:** Workstation
- **Command:**
```
export INCIDENT_ID=INC-$(date -u +%Y%m%d-%H%M); bash scripts/collect-evidence.sh
```
- **Expected output:** evidence/incidents/$INCIDENT_ID/evidence.json; health shows arc-hyperv-demo unhealthy; 'Secret scan: clean'
- **Instructor says:** "Deterministic queries built this package. GUIDs and IPs are already redacted. This is the only thing the AI will see."
- **Audience should notice:** Curated evidence, not raw logs.
- **What can fail:** Query failure; secret detected.
- **Recovery action:** Fix query; investigate and re-run.
- **Verification command:** `jq .health evidence/incidents/$INCIDENT_ID/evidence.json`
- **Switch to backup:** Use evidence/sanitized-example.json.

## 17. Natural-language incident question

- **Environment:** Workstation
- **Command:**
```
export EVIDENCE_FILE=evidence/incidents/$INCIDENT_ID/evidence.json; export QUESTION='What broke in the hybrid estate, which server is affected, and where is it hosted?'
```
- **Expected output:** Question staged
- **Instructor says:** "Plain English. No KQL from the audience."
- **Audience should notice:** The question, not the model, is in control of scope.
- **What can fail:** —
- **Recovery action:** —
- **Verification command:** `—`
- **Switch to backup:** —

## 18. AI-generated explanation

- **Environment:** Workstation
- **Command:**
```
bash ai/explain-incident.sh | jq .
```
- **Expected output:** JSON: affected_machine arc-hyperv-demo; hosting_origin Hyper-V; evidence_cited [...]; confidence high; requires_human_approval true
- **Instructor says:** "Labelled AI-generated. Every sentence cites a path in the evidence. It says what it does not know."
- **Audience should notice:** Citations; uncertainty; no commands.
- **What can fail:** Endpoint 401/403 (role); ungrounded answer.
- **Recovery action:** Assign Azure AI User / Cognitive Services OpenAI User; use backup/05.
- **Verification command:** `grep -c evidence_cited`
- **Switch to backup:** Backup/05-ai-explanation.md.

## 19. AI-generated change proposal

- **Environment:** Workstation
- **Command:**
```
jq '{proposed_runbook, requires_human_approval}' evidence/incidents/$INCIDENT_ID/ai-explanation.json
```
- **Expected output:** RB-001, true
- **Instructor says:** "It proposes a runbook ID, not a shell command. The command lives in Git at a pinned commit."
- **Audience should notice:** Runbook catalog is the only action vocabulary.
- **What can fail:** Model proposes something not in catalog.
- **Recovery action:** Reject; show refusal path; use backup.
- **Verification command:** `Compare with evidence approved_runbooks`
- **Switch to backup:** Backup/05.

## 20. Human approval

- **Environment:** Browser (GitHub)
- **Command:**
```
gh workflow run remediate-rb-001 -f target=arc-hyperv-demo -f incident_id=$INCIDENT_ID; then reviewer approves in Actions → environment
```
- **Expected output:** Job paused 'Waiting for review' → Approved by <reviewer>
- **Instructor says:** "A named human, who is not me, approves exactly this runbook on exactly this machine. That record is permanent."
- **Audience should notice:** Approval is outside the model and outside my account.
- **What can fail:** Reviewer unavailable; environment misconfigured.
- **Recovery action:** Second reviewer on standby; else backup/06.
- **Verification command:** `Run shows approval event`
- **Switch to backup:** Backup/06-approval-record.md.

## 21. Deterministic remediation

- **Environment:** GitHub Actions → Azure → Hyper-V guest
- **Command:**
```
(workflow step) az connectedmachine extension create ... CustomScript ... remediate.sh with REMEDIATION_TARGET=arc-hyperv-demo
```
- **Expected output:** Step succeeds; runbook-hashes.txt artifact
- **Instructor says:** "Azure Arc delivers the approved script to the local VM through the same extension framework Azure uses for its own VMs. One target, one action."
- **Audience should notice:** Hash of the script = what was reviewed.
- **What can fail:** Extension failure; guest offline.
- **Recovery action:** Lab-only fallback: run `APPROVAL_ID=APR-x REMEDIATION_TARGET=arc-hyperv-demo bash scripts/remediate.sh` in the console after approval; or backup/08.
- **Verification command:** `az connectedmachine extension list`
- **Switch to backup:** Backup/08.

## 22. Health verification

- **Environment:** Workstation
- **Command:**
```
az monitor log-analytics query -w $LAW_CUSTOMER_ID --analytics-query "$(cat queries/arc-health.kql)" -o table
```
- **Expected output:** arc-hyperv-demo healthy (after 1–3 min)
- **Instructor says:** "Same query as before the fault. Only now do we say 'recovered'."
- **Audience should notice:** unhealthy → healthy transition.
- **What can fail:** Ingestion lag.
- **Recovery action:** Show verify-health.sh exit 0 as interim; wait.
- **Verification command:** `Same query`
- **Switch to backup:** Backup/07.

## 23. Incident-documentation update

- **Environment:** Workstation
- **Command:**
```
jq --slurpfile ai evidence/incidents/$INCIDENT_ID/ai-explanation.json '. + {ai_explanation:$ai[0]}' evidence/incidents/$INCIDENT_ID/evidence.json > tmp && mv tmp evidence/incidents/$INCIDENT_ID/evidence.json  # add approval/execution/verification blocks; git checkout -b incident/$INCIDENT_ID; commit; PR
```
- **Expected output:** PR with sanitized incident record
- **Instructor says:** "Evidence, approval, action, result, rollback: one document, reviewed like code."
- **Audience should notice:** Documentation is the output of the flow, not a separate demo.
- **What can fail:** GUID leak fails the sanitization gate.
- **Recovery action:** Redact and re-commit.
- **Verification command:** `secret-scan workflow green`
- **Switch to backup:** N/A

## 24. AWS cleanup

- **Environment:** Workstation
- **Command:**
```
cd terraform/aws && terraform destroy -auto-approve
```
- **Expected output:** Destroy complete
- **Instructor says:** "Destroy immediately; the ExpirationDate tag is a promise, not a plan."
- **Audience should notice:** Nothing billable remains.
- **What can fail:** State lock.
- **Recovery action:** terraform force-unlock; delete manually.
- **Verification command:** `aws ec2 describe-instances --filters Name=tag:Session,Values=AzureArcHybrid`
- **Switch to backup:** N/A

## 25. Google Cloud cleanup

- **Environment:** Workstation
- **Command:**
```
cd terraform/gcp && terraform destroy -auto-approve
```
- **Expected output:** Destroy complete
- **Instructor says:** —
- **Audience should notice:** —
- **What can fail:** API disable prompts.
- **Recovery action:** Re-run.
- **Verification command:** `gcloud compute instances list --filter=labels.session=azurearchybrid`
- **Switch to backup:** N/A

## 26. Azure cleanup

- **Environment:** Workstation
- **Command:**
```
az connectedmachine delete -n arc-hyperv-demo -g $AZURE_RESOURCE_GROUP --yes (×3 if guests already gone); cd terraform/azure && terraform destroy -auto-approve
```
- **Expected output:** RG deleted
- **Instructor says:** —
- **Audience should notice:** —
- **What can fail:** RG delete blocked by lock.
- **Recovery action:** Remove lock.
- **Verification command:** `az group exists -n $AZURE_RESOURCE_GROUP → false`
- **Switch to backup:** N/A

## 27. Hyper-V VM cleanup

- **Environment:** Instructor laptop
- **Command:**
```
.\Remove-ArcHyperVVM.ps1 -Force
```
- **Expected output:** VM removed; VHDX deleted
- **Instructor says:** —
- **Audience should notice:** —
- **What can fail:** VM locked by console.
- **Recovery action:** Close vmconnect; retry.
- **Verification command:** `Get-VM arc-hyperv-demo → error`
- **Switch to backup:** N/A

## 28. Credential and temporary-permission removal

- **Environment:** Workstation
- **Command:**
```
az logout; aws sso logout; gcloud auth revoke --all; gcloud auth application-default revoke; az ad app federated-credential delete ...; az ad app delete ...; remove GitHub environment reviewers/variables
```
- **Expected output:** No identities listed
- **Instructor says:** "The last step of a good demo is making sure it cannot be run by accident tomorrow."
- **Audience should notice:** Temporary access has an end.
- **What can fail:** Forgotten role assignment.
- **Recovery action:** az role assignment list --all --assignee <app>; delete.
- **Verification command:** `az account list → empty; gcloud auth list → empty`
- **Switch to backup:** N/A
