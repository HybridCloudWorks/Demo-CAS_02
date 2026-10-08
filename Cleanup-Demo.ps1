<#
.SYNOPSIS
  Removes everything the Demo-CAS_02 lab created and verifies nothing billable remains.
  Scope: AWS stack, GCP stack, Azure Arc machines + the demo resource group, the GitHub OIDC app registration,
         the GitHub environment / variables / reviewer. Cloud resources only; local files are kept unless -RemoveLocalState. Hyper-V is not involved.
  Never touches: pre-existing Arc servers or resource groups outside -ResourceGroup.
.NOTES
  Settings: copy demo-settings.example.psd1 to demo-settings.psd1 (git-ignored) and fill it in.
  Parameters passed on the command line override the settings file.
#>
[CmdletBinding()]
param(
    [string]$ResourceGroup = 'rg-arc-hybrid-demo',
    [string]$AwsRegion     = 'us-east-1',
    [string]$GcpProject,
    [string]$Repo,                                               # <owner>/<repo>
    [string]$Reviewer,                                           # collaborator added by Setup-ApprovalGate.ps1; removed here
    [string]$AppName       = 'gh-oidc-demo-cas02-remediation',
    [string]$Environment   = 'remediation-approval',
    [switch]$RemoveLocalState   # off by default: local Terraform state/plans/tfvars are left in place
)
$ErrorActionPreference = 'Continue'
$env:MSYS_NO_PATHCONV = '1'; $env:CLOUDSDK_BILLING_QUOTA_PROJECT = ''
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
function Step($m) { Write-Host "`n== $m" -ForegroundColor Cyan }

$settingsPath = Join-Path $root 'demo-settings.psd1'
if (Test-Path $settingsPath) {
    $settings = Import-PowerShellDataFile $settingsPath
    foreach ($k in $settings.Keys) {
        if ($MyInvocation.MyCommand.Parameters.ContainsKey($k) -and -not $PSBoundParameters.ContainsKey($k)) { Set-Variable -Name $k -Value $settings[$k] }
    }
}
$missing = 'GcpProject', 'Repo', 'Reviewer' | Where-Object { (Get-Variable $_ -ValueOnly) -notmatch '^[^<]+$' }
if ($missing) { throw "Set $($missing -join ', ') in demo-settings.psd1 (copy demo-settings.example.psd1) or pass them as parameters." }

Step 'Azure Arc machine resources'
foreach ($m in 'arc-aws-demo', 'arc-gcp-demo') { az connectedmachine delete -n $m -g $ResourceGroup --yes --only-show-errors 2>$null; Write-Host "deleted $m" }

Step 'AWS: terraform destroy'
Push-Location (Join-Path $root 'terraform\aws'); terraform destroy -auto-approve -input=false; Pop-Location
Step 'GCP: terraform destroy'
Push-Location (Join-Path $root 'terraform\gcp'); terraform destroy -auto-approve -input=false; Pop-Location

Step "Azure: delete resource group $ResourceGroup (includes Defender-added DCRs and solution that Terraform does not own)"
az group delete -n $ResourceGroup --yes --only-show-errors
Push-Location (Join-Path $root 'terraform\azure'); terraform state list 2>$null | ForEach-Object { terraform state rm $_ | Out-Null }; Pop-Location

Step "Entra: delete app registration $AppName (OIDC trust for the workflow)"
$appId = az ad app list --display-name $AppName --query '[0].appId' -o tsv
if ($appId) { az ad app delete --id $appId; Write-Host "deleted $appId" } else { Write-Host 'already gone' }

Step 'GitHub: environment, variables, reviewer'
gh api -X DELETE "repos/$Repo/environments/$Environment" 2>$null
foreach ($v in 'AZURE_CLIENT_ID','AZURE_TENANT_ID','AZURE_SUBSCRIPTION_ID','AZURE_RESOURCE_GROUP','AZURE_LOCATION') { gh variable delete $v -R $Repo 2>$null }
gh api -X DELETE "repos/$Repo/collaborators/$Reviewer" 2>$null

if ($RemoveLocalState) {
    Step 'Local: Terraform state, plans and tfvars (opt-in)'
    foreach ($s in 'aws','gcp','azure') { Remove-Item (Join-Path $root "terraform\$s\terraform.tfstate*"), (Join-Path $root "terraform\$s\tfplan"), (Join-Path $root "terraform\$s\terraform.tfvars") -ErrorAction SilentlyContinue }
}

Step 'Verification'
$left = @()
$ec2 = aws ec2 describe-instances --region $AwsRegion --filters 'Name=tag:Session,Values=AzureArcHybrid' 'Name=instance-state-name,Values=pending,running,stopping,stopped' --query 'Reservations[].Instances[].InstanceId' --output text
if ($ec2) { $left += "AWS EC2: $ec2" }
$tagged = aws resourcegroupstaggingapi get-resources --region $AwsRegion --tag-filters Key=Session,Values=AzureArcHybrid --query 'ResourceTagMappingList[].ResourceARN' --output text
if ($tagged) { $left += "AWS tagged resources: $tagged" }
if (aws iam get-role --role-name arc-aws-demo-ssm-role 2>$null) { $left += 'AWS IAM role arc-aws-demo-ssm-role' }
$gce = gcloud compute instances list --project $GcpProject --filter='labels.session=azurearchybrid' --format='value(name)' 2>$null
if ($gce) { $left += "GCE: $gce" }
$gnet = gcloud compute networks list --project $GcpProject --filter='name=arc-gcp-demo-vpc' --format='value(name)' 2>$null
if ($gnet) { $left += "GCP network: $gnet" }
$gsa = gcloud iam service-accounts list --project $GcpProject --filter='email:arc-gcp-demo-sa@' --format='value(email)' 2>$null
if ($gsa) { $left += "GCP service account: $gsa" }
if ((az group exists -n $ResourceGroup) -eq 'true') { $left += "Azure RG still present (delete may still be running): $ResourceGroup" }
if (az ad app list --display-name $AppName --query '[0].appId' -o tsv) { $left += "Entra app: $AppName" }
$envs = gh api "repos/$Repo/environments" --jq '.environments[].name' 2>$null
if ($envs -contains $Environment) { $left += "GitHub environment $Environment" }
if ($left) { Write-Host "`nREMAINING:" -ForegroundColor Yellow; $left | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow } } else { Write-Host "`nNothing remains. Pre-existing Arc servers outside $ResourceGroup untouched." -ForegroundColor Green }
Write-Host 'Optional: az logout; gcloud auth revoke --all; the SSM plugin and az CLI extensions can stay.'
