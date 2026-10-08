<#
.SYNOPSIS
  Applies the three saved Terraform plans (Azure, AWS, GCP) for the Demo-CAS_02 lab in parallel.
.NOTES
  Hyper-V is not included. Plans were produced by `terraform plan -out=tfplan` in each stack directory
  and must already exist; if Terraform reports a plan as stale, re-run `terraform plan -out=tfplan` there.
  Authentication: az login, aws (current credentials), gcloud application-default credentials.
#>
[CmdletBinding()]
param(
    [string[]]$Stacks = @('azure', 'aws', 'gcp')
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

foreach ($s in $Stacks) {
    $plan = Join-Path $root "terraform\$s\tfplan"
    if (-not (Test-Path $plan)) { throw "Missing saved plan: $plan  (run: cd terraform\$s; terraform plan -out=tfplan)" }
}

Get-Job -Name 'tf-*' -ErrorAction SilentlyContinue | Remove-Job -Force

foreach ($s in $Stacks) {
    $dir = Join-Path $root "terraform\$s"
    Start-Job -Name "tf-$s" -ArgumentList $dir, $s -ScriptBlock {
        param($dir, $s)
        if ($s -eq 'gcp') { $env:CLOUDSDK_BILLING_QUOTA_PROJECT = '' }
        Set-Location $dir
        $start = Get-Date
        terraform apply -input=false -no-color tfplan 2>&1
        "[$s] exit=$LASTEXITCODE elapsed=$([int]((Get-Date) - $start).TotalSeconds)s"
    } | Out-Null
    Write-Host "Started $s apply ..."
}

Write-Host "Waiting for applies (typically 2-5 minutes) ..."
Get-Job -Name 'tf-*' | Wait-Job | Out-Null

$failed = @()
foreach ($s in $Stacks) {
    Write-Host "`n================ $s ================" -ForegroundColor Cyan
    $out = Receive-Job -Name "tf-$s"
    $out | Where-Object { $_ -match 'Creation complete|Apply complete|Error|exit=' } | ForEach-Object { Write-Host $_ }
    if (($out -join "`n") -notmatch 'Apply complete') { $failed += $s; $out | Select-Object -Last 25 | ForEach-Object { Write-Host $_ -ForegroundColor Yellow } }
}
Get-Job -Name 'tf-*' | Remove-Job -Force

Write-Host "`n================ outputs ================" -ForegroundColor Cyan
foreach ($s in $Stacks) {
    if ($failed -contains $s) { continue }
    Write-Host "--- $s" -ForegroundColor Cyan
    Push-Location (Join-Path $root "terraform\$s")
    terraform output -no-color 2>&1 | Where-Object { $_ -notmatch 'sensitive' }
    Pop-Location
}

if ($failed) { Write-Host "`nFAILED: $($failed -join ', ')" -ForegroundColor Red; exit 1 }
Write-Host "`nAll stacks applied. Next: docs/instructor-runbook.md step 8 (guest configuration) and step 9 (Arc onboarding)." -ForegroundColor Green
