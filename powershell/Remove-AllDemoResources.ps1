<#
.SYNOPSIS  One-shot destroy for the whole lab: AWS, Google Cloud, Azure, Hyper-V. Verifies nothing billable remains.
.DESCRIPTION
  Order: Arc resources -> Terraform destroy (aws, gcp) -> Terraform destroy (azure) -> Hyper-V VM -> verification.
  Requires: terraform, az, aws, gcloud on PATH; az login / aws sso login / gcloud auth already done.
  No credentials are read or printed. Exit code 0 = clean; 3 = leftovers detected.
.EXAMPLE
  .\Remove-AllDemoResources.ps1 -ResourceGroup rg-arc-hybrid-demo -AwsRegion us-east-2 -GcpProject my-demo-proj -Confirm:$false
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
  [Parameter(Mandatory)][string]$ResourceGroup,
  [Parameter(Mandatory)][string]$AwsRegion,
  [Parameter(Mandatory)][string]$GcpProject,
  [string]$AwsProfile,
  [string]$VmName = 'arc-hyperv-demo',
  [switch]$SkipHyperV
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$repo = Split-Path -Parent $PSScriptRoot
$left = @()
function Step($m){ Write-Host "`n== $m ==" -ForegroundColor Cyan }
if ($AwsProfile) { $env:AWS_PROFILE = $AwsProfile }

if (-not $PSCmdlet.ShouldProcess('all demo resources', 'DESTROY')) { return }

Step 'Azure Arc machines (delete resource records; agents can be disconnected in-guest first)'
foreach ($m in 'arc-hyperv-demo','arc-aws-demo','arc-gcp-demo') {
  az connectedmachine delete --name $m --resource-group $ResourceGroup --yes --only-show-errors 2>$null
}

Step 'AWS: terraform destroy'
Push-Location (Join-Path $repo 'terraform/aws'); terraform destroy -auto-approve -input=false; Pop-Location
Step 'GCP: terraform destroy'
Push-Location (Join-Path $repo 'terraform/gcp'); terraform destroy -auto-approve -input=false; Pop-Location
Step 'Azure: terraform destroy (RG, workspace, DCR, policy)'
Push-Location (Join-Path $repo 'terraform/azure'); terraform destroy -auto-approve -input=false; Pop-Location

if (-not $SkipHyperV) { Step 'Hyper-V'; & (Join-Path $PSScriptRoot 'Remove-ArcHyperVVM.ps1') -VmName $VmName -Force }

Step 'Verification (should all be empty)'
$ec2 = aws ec2 describe-instances --region $AwsRegion --filters "Name=tag:Session,Values=AzureArcHybrid" "Name=instance-state-name,Values=pending,running,stopping,stopped" --query 'Reservations[].Instances[].InstanceId' --output text
if ($ec2) { $left += "AWS EC2: $ec2" }
$vol = aws ec2 describe-volumes --region $AwsRegion --filters "Name=tag:Session,Values=AzureArcHybrid" --query 'Volumes[].VolumeId' --output text
if ($vol) { $left += "AWS volumes: $vol" }
$eip = aws ec2 describe-addresses --region $AwsRegion --query 'Addresses[?AssociationId==null].PublicIp' --output text
if ($eip) { $left += "AWS unattached EIPs: $eip" }
$gce = gcloud compute instances list --project $GcpProject --filter="labels.session=azurearchybrid" --format="value(name)"
if ($gce) { $left += "GCE instances: $gce" }
$gdisk = gcloud compute disks list --project $GcpProject --filter="labels.session=azurearchybrid" --format="value(name)"
if ($gdisk) { $left += "GCE disks: $gdisk" }
$gaddr = gcloud compute addresses list --project $GcpProject --format="value(name)"
if ($gaddr) { $left += "GCP addresses: $gaddr" }
$rg = az group exists --name $ResourceGroup
if ($rg -eq 'true') { $left += "Azure RG still exists: $ResourceGroup" }
if (-not $SkipHyperV -and (Get-VM -Name $VmName -ErrorAction SilentlyContinue)) { $left += "Hyper-V VM still exists: $VmName" }

if ($left) { Write-Host "LEFTOVERS:" -ForegroundColor Red; $left | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }; exit 3 }
Write-Host 'CLEAN: no demo resources remain.' -ForegroundColor Green
Write-Host 'Reminder: revoke temporary access -> az logout; aws sso logout; gcloud auth revoke --all; remove any GitHub environment secrets/federated credentials.' -ForegroundColor Yellow
exit 0
