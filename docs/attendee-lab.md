# Attendee lab guide — Azure Arc hybrid incident lifecycle

> **Safety and cost warning.** Steps marked **💲** create billable cloud resources (EC2, Compute Engine, Log Analytics, Machine Configuration ≈ $6/server/month pro-rated). Destroy everything when you finish (Section 12). Never paste credentials into files, prompts, or chat. Use a sandbox subscription/account/project you own.

> **Legend:** 🧑‍🏫 = instructor-only step (observe during the session) · 👩‍💻 = attendee step (do it yourself, during or after the event). Access model for the live event: `<AUDIENCE_LAB_ACCESS_MODEL>` (observe / build-your-own). 

## 1. Prerequisites
- A Windows 11 Pro/Enterprise/Education PC with Hyper-V, 16 GB RAM, 60 GB free disk (or skip Hyper-V and use only AWS + GCP).
- Sandbox Azure subscription (role: *Azure Connected Machine Onboarding* + *Contributor* on **one** resource group), AWS account (sandbox), Google Cloud project (sandbox, billing enabled).
- GitHub account with a fork of `https://github.com/hcw-architect/Demo-CAS_02`.

## 2. Local tool installation checklist
`git` · `terraform ≥ 1.9` · `az` (Azure CLI) + `az extension add --name resource-graph --name connectedmachine` · `aws` CLI v2 + Session Manager plugin · `gcloud` CLI · PowerShell 7 · an SSH client · `jq` (or `python3 -m json.tool`).

## 3. Authentication (no secrets)
```
cp .env.example .env         # fill placeholders; .env is git-ignored
source .env
az login --use-device-code && az account set --subscription "$AZURE_SUBSCRIPTION_ID"
aws sso login --profile "$AWS_PROFILE" && aws sts get-caller-identity
gcloud auth login && gcloud auth application-default login && gcloud config set project "$CLOUDSDK_CORE_PROJECT"
```
Everything above produces short-lived tokens in the tools' own caches. Nothing is written into the repo.

## 4. Platform requirements
| Hyper-V | AWS | Google Cloud | Azure |
|---|---|---|---|
| Hyper-V enabled, Default Switch, Ubuntu 24.04 Server ISO (SHA256 verified) | Region with t3.micro, SSM enabled, IAM rights to create VPC/EC2/IAM role | Project with Compute/IAP/OS Login APIs enabled (Terraform enables them), roles Compute Admin + Service Account User + IAP tunnel user | Providers HybridCompute, GuestConfiguration, HybridConnectivity registered; dedicated RG |

## 5. Step-by-step deployment
1. 👩‍💻 **Azure prerequisites** 💲 (workspace is pay-per-GB): `cd terraform/azure && cp terraform.tfvars.example terraform.tfvars` → edit → `terraform init && terraform validate && terraform plan -out tfplan && terraform apply tfplan`. Expected: RG, Log Analytics workspace, DCR, 4 policy assignments.
2. 👩‍💻 **Hyper-V VM**: `powershell/Test-HyperVPrerequisites.ps1 ...` then `powershell/New-ArcHyperVVM.ps1 -SwitchName 'Default Switch' -IsoPath <LINUX_IMAGE_PATH> -VmPath <HYPERV_VM_PATH>`. Install Ubuntu in the console (hostname **arc-hyperv-demo**), then `sudo bash scripts/configure-demo-service.sh`.
3. 👩‍💻 **AWS VM** 💲: `cd terraform/aws` → tfvars → `init/validate/plan/apply`. Access: `aws ssm start-session --target $(terraform output -raw instance_id)`.
4. 👩‍💻 **GCP VM** 💲: `cd terraform/gcp` → tfvars → `init/validate/plan/apply`. Access: `terraform output -raw iap_ssh_command | bash`.
5. 👩‍💻 In each guest: `sudo cloud-init status --wait` (AWS/GCP) and `bash scripts/preflight.sh` → PREFLIGHT PASS.

## 6. Arc onboarding
In each guest (copy the scripts via SSM/IAP session or `git clone`):
```
export ARC_SUBSCRIPTION_ID=<AZURE_SUBSCRIPTION_ID> ARC_TENANT_ID=<AZURE_TENANT_ID> ARC_RESOURCE_GROUP=<AZURE_RESOURCE_GROUP> ARC_LOCATION=<AZURE_LOCATION>
export ARC_CLOUD_ORIGIN=Hyper-V   # or AWS, or GCP
export ARC_RESOURCE_NAME=$(hostname)
sudo -E bash scripts/onboard-arc.sh      # follow the device-code prompt within 5 minutes
sudo azcmagent show | grep 'Agent Status'
```

## 7. Inventory validation
`az graph query -q "$(sed "s/<AZURE_RESOURCE_GROUP>/$AZURE_RESOURCE_GROUP/" queries/arc-inventory.kql)" -o table` → three machines, Connected, CloudOrigin Hyper-V / AWS / GCP. Try `queries/resource-graph-query.kql` section 1 for the per-origin count.

**Knowledge check:** which column proves hosting origin — `cloudOrigin` (tag) or `detectedCloud` (agent)? *Answer: neither is cryptographic proof; the tag is a claim set at onboarding, the detection is the agent's observation; use both and validate.*

## 8. Health validation
`az monitor log-analytics query -w $LAW_CUSTOMER_ID --analytics-query "$(cat queries/arc-health.kql)" -o table` → healthy ×3 (allow 2–5 minutes after AMA is installed by policy). Locally: `bash scripts/verify-health.sh` → exit 0.

## 9. Fault injection (Hyper-V only)
On **arc-hyperv-demo**: `bash scripts/inject-safe-fault.sh`. Try it on arc-aws-demo too — it must print **REFUSED**. Re-run the health query: Hyper-V unhealthy, AWS and GCP healthy.

## 10. Evidence, explanation, approval simulation
1. `INCIDENT_ID=INC-$(date -u +%Y%m%d-%H%M) bash scripts/collect-evidence.sh` → sanitized JSON.
2. Optional AI step (needs a Foundry model deployment and the *Azure AI User* role): `EVIDENCE_FILE=... bash ai/explain-incident.sh`. Without a model, read `backup/05-ai-explanation.md` and compare it to your evidence.
3. Approval simulation: in your fork, create environment `remediation-approval` with a required reviewer (a colleague), then `gh workflow run remediate-rb-001 -f target=arc-hyperv-demo -f incident_id=$INCIDENT_ID`. Observe the job wait. If you have no reviewer, record an approval line manually in the incident JSON and run the lab-only path in Section 11.

## 11. Remediation and verification
- Workflow path: reviewer approves → extension runs `remediate.sh` on arc-hyperv-demo.
- Lab-only path (no workflow): on arc-hyperv-demo `APPROVAL_ID=APR-LAB REMEDIATION_TARGET=arc-hyperv-demo bash scripts/remediate.sh` → RESULT: recovered.
- Verify with the **same** health query from Section 8. Then update the incident JSON (`approval`, `execution`, `verification`) and validate it against `evidence/incident-schema.json`.

## 12. Cleanup 💲 (do this now)
`pwsh powershell/Remove-AllDemoResources.ps1 -ResourceGroup <AZURE_RESOURCE_GROUP> -AwsRegion <AWS_REGION> -GcpProject <GCP_PROJECT_ID>` → `CLEAN`. Then `az logout; aws sso logout; gcloud auth revoke --all`.

## 13. Knowledge-check questions
1. Which of the three machines runs on Hyper-V, AWS, GCP? *(arc-hyperv-demo / arc-aws-demo / arc-gcp-demo)*
2. Did Azure Arc move any machine into Azure? *(No; it created an Azure resource identity and management relationship.)*
3. Why is there no Azure VM in the lab? *(An Azure VM already has native Azure management; Arc is for machines outside Azure.)*
4. Which capabilities in the lab depended on Arc? *(Resource identity + tags, Resource Graph inventory, Policy/Machine Configuration, AMA extension via DCR, extension-based execution of the approved runbook.)*
5. What may the AI layer do, and what may it never do? *(Explain, cite, compare, propose a runbook ID, state uncertainty; never write/execute commands, bypass approval, expand scope, touch credentials, or claim success before verification.)*
6. What proves recovery? *(The same `arc-health.kql` query that detected the fault, now showing healthy.)*
7. Name two reasons direct agent onboarding was chosen over the multicloud connector for the live demo. *(Immediate result; connector is periodic and preview for GCP; connector skips already-Arc-enabled machines.)*
8. What does Machine Configuration cost on an Arc server? *($6 per server per month, pro-rated hourly.)*
