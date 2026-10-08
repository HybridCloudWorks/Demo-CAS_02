<#
.SYNOPSIS
  One-time setup of the human approval gate for the RB-001 workflow (.github/workflows/remediate.yml).
  Azure side : Entra app registration + service principal, GitHub OIDC federated credential (no secret),
               least-privilege role on the demo resource group.
  GitHub side: environment 'remediation-approval' with a required reviewer who is not the dispatcher,
               and the repository variables the workflow reads via vars.*.
.NOTES
  Settings: copy demo-settings.example.psd1 to demo-settings.psd1 (git-ignored) and fill it in.
  Parameters passed on the command line override the settings file.
  Run with az logged in as an Owner of the subscription and gh authenticated as the repository admin
  (the account that dispatches the workflow, which must differ from -Reviewer).
  Idempotent: safe to re-run.
#>
[CmdletBinding()]
param(
    [string]$Repo,                                               # <owner>/<repo>
    [string]$Reviewer,                                           # GitHub login that approves; must not be the dispatcher
    [string]$SubscriptionId,
    [string]$TenantId,
    [string]$ResourceGroup  = 'rg-arc-hybrid-demo',
    [string]$Location       = 'centralus',
    [string]$AppName        = 'gh-oidc-demo-cas02-remediation',
    [string]$Environment    = 'remediation-approval'
)
$ErrorActionPreference = 'Stop'
$env:MSYS_NO_PATHCONV = '1'
function Step($m) { Write-Host "`n== $m" -ForegroundColor Cyan }

$settingsPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'demo-settings.psd1'
if (Test-Path $settingsPath) {
    $settings = Import-PowerShellDataFile $settingsPath
    foreach ($k in $settings.Keys) {
        if ($MyInvocation.MyCommand.Parameters.ContainsKey($k) -and -not $PSBoundParameters.ContainsKey($k)) { Set-Variable -Name $k -Value $settings[$k] }
    }
}
$missing = 'Repo', 'Reviewer', 'SubscriptionId', 'TenantId' | Where-Object { (Get-Variable $_ -ValueOnly) -notmatch '^[^<]+$' }
if ($missing) { throw "Set $($missing -join ', ') in demo-settings.psd1 (copy demo-settings.example.psd1) or pass them as parameters." }

# ---------------------------------------------------------------- Azure
Step "Entra app registration '$AppName'"
$appId = az ad app list --display-name $AppName --query '[0].appId' -o tsv
if (-not $appId) { $appId = az ad app create --display-name $AppName --sign-in-audience AzureADMyOrg --query appId -o tsv }
Write-Host "appId = $appId"
$spId = az ad sp show --id $appId --query id -o tsv 2>$null
if (-not $spId) { $spId = az ad sp create --id $appId --query id -o tsv }
Write-Host "service principal objectId = $spId"

Step "Federated credentials for GitHub environment '$Environment' (OIDC, no secret)"
# GitHub now embeds owner and repository IDs in the OIDC subject
# (repo:OWNER@OWNER_ID/REPO@REPO_ID:environment:NAME). Register both the classic and the ID-qualified form.
$owner, $name = $Repo.Split('/')
$ids = gh api "repos/$Repo" --jq '"\(.owner.id) \(.id)"'
$ownerId, $repoId = $ids.Split(' ')
$subjects = @{
    'github-remediation-approval'     = "repo:$Repo`:environment:$Environment"
    'github-remediation-approval-ids' = "repo:$owner@$ownerId/$name@$repoId`:environment:$Environment"
}
foreach ($fcName in $subjects.Keys) {
    $have = az ad app federated-credential list --id $appId --query "[?name=='$fcName'] | length(@)" -o tsv
    if ($have -ne '1') {
        $fc = @{
            name        = $fcName
            issuer      = 'https://token.actions.githubusercontent.com'
            subject     = $subjects[$fcName]
            audiences   = @('api://AzureADTokenExchange')
            description = 'RB-001 remediation workflow; token issued only for jobs running in the approval environment'
        } | ConvertTo-Json -Compress
        $tmp = New-TemporaryFile; Set-Content -Path $tmp -Value $fc -Encoding ascii
        az ad app federated-credential create --id $appId --parameters "@$tmp" --query '{name:name,subject:subject}' -o tsv
        Remove-Item $tmp
    } else { Write-Host "$fcName already present" }
}

Step "Role on the demo resource group (least privilege for extension create/delete)"
$scope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup"
az role assignment create --assignee-object-id $spId --assignee-principal-type ServicePrincipal `
    --role 'Azure Connected Machine Resource Administrator' --scope $scope --only-show-errors `
    --query '{role:roleDefinitionName}' -o tsv

# ---------------------------------------------------------------- GitHub
Step "Reviewer '$Reviewer' must be able to see the repository"
$collabs = gh api "repos/$Repo/collaborators" --jq '.[].login'
if ($collabs -notcontains $Reviewer) {
    gh api -X PUT "repos/$Repo/collaborators/$Reviewer" -f permission=push | Out-Null
    Write-Host "Invitation sent to $Reviewer. Accept it from that account (github.com/notifications) before the demo." -ForegroundColor Yellow
} else { Write-Host "already a collaborator" }
$reviewerId = gh api "users/$Reviewer" --jq '.id'

Step "Environment '$Environment' with required reviewer and self-review blocked"
$body = @{ reviewers = @(@{ type = 'User'; id = [int]$reviewerId }); prevent_self_review = $true; wait_timer = 0 } | ConvertTo-Json -Compress
$body | gh api -X PUT "repos/$Repo/environments/$Environment" --input - --jq '{name:.name,reviewers:[.protection_rules[]?|select(.type=="required_reviewers")|.reviewers[].reviewer.login],prevent_self_review:(.protection_rules[]?|select(.type=="required_reviewers")|.prevent_self_review)}'

Step "Repository variables read by the workflow (vars.*)"
gh variable set AZURE_CLIENT_ID       -R $Repo -b $appId
gh variable set AZURE_TENANT_ID       -R $Repo -b $TenantId
gh variable set AZURE_SUBSCRIPTION_ID -R $Repo -b $SubscriptionId
gh variable set AZURE_RESOURCE_GROUP  -R $Repo -b $ResourceGroup
gh variable set AZURE_LOCATION        -R $Repo -b $Location
gh variable list -R $Repo

Step "Done"
Write-Host "Dispatch test (as the repository admin, not $Reviewer):  gh workflow run remediate-rb-001 -R $Repo -f target=arc-aws-demo -f incident_id=INC-TEST"
Write-Host "Then approve the pending deployment from the $Reviewer account under Actions -> the run -> Review deployments."
