# Cleanup and credential revocation

One shot: `powershell/Remove-AllDemoResources.ps1 -ResourceGroup <AZURE_RESOURCE_GROUP> -AwsRegion <AWS_REGION> -GcpProject <GCP_PROJECT_ID>`. Manual order if preferred:

1. **In each guest (optional but tidy):** `scripts/cleanup.sh` → `azcmagent disconnect` removes the Azure resource.
2. **Arc resources (if guests are gone):** `az connectedmachine delete -n <machine> -g <AZURE_RESOURCE_GROUP> --yes` for each of the three.
3. **AWS:** `cd terraform/aws && terraform destroy`. Verify: `aws ec2 describe-instances --filters Name=tag:Session,Values=AzureArcHybrid --query 'Reservations[].Instances[].[InstanceId,State.Name]'`, `aws ec2 describe-volumes --filters Name=status,Values=available`, `aws ec2 describe-addresses`.
4. **Google Cloud:** `cd terraform/gcp && terraform destroy`. Verify: `gcloud compute instances list --filter="labels.session=azurearchybrid"`, `gcloud compute disks list`, `gcloud compute addresses list`.
5. **Azure:** `cd terraform/azure && terraform destroy` (deletes RG, workspace, DCR, assignments). Verify: `az group exists -n <AZURE_RESOURCE_GROUP>` → false; `az graph query -q "resources | where tags['Session']=='AzureArcHybrid' | count"` → 0.
6. **Hyper-V:** `powershell/Remove-ArcHyperVVM.ps1 -Force`. Verify: `Get-VM arc-hyperv-demo` → not found; VHDX gone; checkpoints gone.
7. **Identities and permissions:** `az logout`; `aws sso logout`; `gcloud auth revoke --all`; delete the GitHub OIDC app registration/federated credential; remove environment reviewers; delete any temporary role assignments: `az role assignment list -g <AZURE_RESOURCE_GROUP>` should be empty (RG deleted).
8. **Billing check next day:** Azure Cost Management filtered by tag `Session=AzureArcHybrid`; AWS Cost Explorer by tag; GCP Billing by label — all should be zero after the destroy date.

Matching deployment → cleanup: `New-ArcHyperVVM.ps1` ↔ `Remove-ArcHyperVVM.ps1`; `terraform apply` (aws/gcp/azure) ↔ `terraform destroy` in the same folder; `onboard-arc.sh` ↔ `cleanup.sh` / `az connectedmachine delete`; `configure-demo-service.sh` ↔ `cleanup.sh`.
