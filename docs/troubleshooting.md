# Troubleshooting decision trees

Format: **Symptom → Check → Fix → If still failing**. Switch to the backup demo (docs/demo-fallback.md) the moment a fix would take more than 2 minutes on stage.

## Hyper-V
- **Hyper-V unavailable** → `Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All` → Enable + reboot; Home edition cannot → use a pre-recorded Hyper-V clip + backup.
- **VM does not start** → `Get-VM | fl State,Status`; event log Hyper-V-Worker → free memory (close apps, lower StartupBytes), verify VHDX path → backup.
- **Secure Boot problem (boot loops / "Image failed to verify")** → `Get-VMFirmware` → `Set-VMFirmware -SecureBootTemplate MicrosoftUEFICertificateAuthority` (Linux needs the UEFI CA template) → disable Secure Boot for the lab only, note it.
- **No virtual-switch connectivity** → `Get-VMSwitch`, `Get-VMNetworkAdapter -VMName arc-hyperv-demo` → attach to `Default Switch` (NAT) → host VPN/firewall blocking NAT: disconnect VPN.
- **No DHCP address** → in guest `ip a`, `networkctl` → `sudo netplan apply`; restart `Default Switch` adapter on host → static IP in guest on the Default Switch subnet.
- **DNS failure** → `resolvectl status`, `getent hosts login.microsoftonline.com` → set `DNS=1.1.1.1 8.8.8.8` in netplan/systemd-resolved → host-level DNS blocked: hotspot.
- **Linux installation failure (Path A)** → ISO SHA256 mismatch? Re-download; check 40 GB disk; → use Path B VHDX.
- **Host resource pressure** → Task Manager, `Get-VM | select MemoryAssigned` → reduce to 2 GB startup / 1 vCPU; close browsers → run the VM pre-onboarded only, do not rebuild live.

## AWS
- **Authentication failure** → `aws sts get-caller-identity` → `aws sso login --profile <AWS_PROFILE>`; check `AWS_PROFILE` export → use backup for the AWS column.
- **Region mismatch** → `aws configure get region`, tfvars `aws_region` → align; SSM parameter is region-specific.
- **Instance quota** → `aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A` → use t3a.micro or another region.
- **Image lookup failure** → `aws ssm get-parameter --name /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id` → fall back to `data "aws_ami"` filter in README.
- **SSM unavailable** → `aws ssm describe-instance-information` empty → wait 2–3 min after boot; check instance profile and egress 443; Session Manager plugin installed on workstation.
- **IAM permission failure** → error names the action → sandbox account with sufficient rights; never add `*:*` to the instance role.
- **No outbound connectivity** → SG egress rules, route table to IGW, `map_public_ip_on_launch` → `terraform plan` shows drift; re-apply.

## Google Cloud
- **Authentication failure** → `gcloud auth list`, `gcloud auth application-default print-access-token >/dev/null` → `gcloud auth login` + `application-default login`.
- **Wrong project** → `gcloud config get-value project` vs tfvars → `gcloud config set project <GCP_PROJECT_ID>`.
- **API not enabled** → error "API has not been used" → `terraform apply` enables compute/iap/oslogin; wait 1–2 min and re-apply.
- **Zone capacity** → "ZONE_RESOURCE_POOL_EXHAUSTED" → change `gcp_zone` to another zone in the region.
- **Machine-type availability** → `gcloud compute machine-types list --filter="zone:<GCP_ZONE> AND name:e2-micro"` → use e2-small.
- **Service-account permission failure** → "Permission iam.serviceAccounts.actAs denied" → grant Service Account User to the human in the demo project.
- **OS Login or IAP failure** → `gcloud compute ssh --tunnel-through-iap` → check firewall 35.235.240.0/20, roles osAdminLogin + iap.tunnelResourceAccessor, `enable-oslogin=TRUE`.
- **VM Manager prerequisite failure** → only relevant to the connector path (preview) → not used live; mention as architecture option.

## Azure Arc
- **Agent installation failure** → `apt-get install azcmagent` output; `dpkg -l azcmagent` → verify packages.microsoft.com reachable; OS on supported list (24.04 yes).
- **Onboarding permission failure** → "AuthorizationFailed" → grant *Azure Connected Machine Onboarding* on the RG to the signing-in user.
- **Duplicate machine identity** → "resource already exists" or two VMs flapping → you cloned a connected VM; `azcmagent disconnect` on the clone, delete the resource, reconnect with a unique `--resource-name`.
- **Disconnected status** → `azcmagent show`, `sudo journalctl -u himdsd -n 50` → fix outbound 443; agent heartbeats every 5 min; Expired after 45 days offline.
- **Proxy issue** → `azcmagent config get proxy.url` → set `proxy.url` and bypass list; Log Analytics gateway is not supported as a proxy.
- **TLS / certificate issue** → `openssl s_client -connect gbl.his.arc.azure.com:443` shows interception → add inspection bypass for Arc endpoints; check system time.
- **Resource-provider registration issue** → `az provider show -n Microsoft.HybridCompute --query registrationState` → `az provider register` (HybridCompute, GuestConfiguration, HybridConnectivity).
- **Region / resource-group mismatch** → ensure `--location` is a supported Arc region and equals the RG's region used by policy; metadata location does not move workloads.
- **Extension deployment failure** → `az connectedmachine extension list -g <RG> --machine-name <m>` → check `provisioningState`/status message; extension allowlist may block; retry after deleting the failed extension.

## Demonstration
- **Health query returns no data** → AMA extension provisioned? DCR associated? `sudo systemctl status arc-demo-heartbeat.timer`; ingestion lag 2–5 min → use `verify-health.sh` locally and the captured query while waiting.
- **Tags are missing** → `az connectedmachine show -n <m> -g <RG> --query tags` → `az tag update --operation merge --resource-id <id> --tags CloudOrigin=...`; remember tags are claims.
- **AI response is not grounded** → check it cited evidence paths; re-run with temperature 0 and the system prompt; if it still invents, use `backup/05-ai-explanation.md`.
- **Approval does not trigger** → environment name in workflow equals the repo environment; required reviewer configured; reviewer is not the dispatcher.
- **Remediation targets the wrong server** → impossible by design: workflow input is a single-choice list and `remediate.sh` refuses when `hostname != REMEDIATION_TARGET`. If the hostname differs from the Arc name, fix the hostname, not the guard.
- **Verification query does not update** → wait one heartbeat (60 s) + ingestion; show `verify-health.sh` output as interim proof; never declare success before the query flips.
- **Cleanup leaves resources behind** → `Remove-AllDemoResources.ps1` prints LEFTOVERS; delete by ID; check for a failed `terraform destroy` (state lock) and re-run.
