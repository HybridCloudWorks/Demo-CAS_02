<#
.SYNOPSIS  Stop and delete arc-hyperv-demo and its virtual disk(s). Idempotent.
.DESCRIPTION  Run scripts/cleanup.sh inside the guest FIRST (azcmagent disconnect) when possible; otherwise
  delete the Arc resource with: az connectedmachine delete -n arc-hyperv-demo -g <AZURE_RESOURCE_GROUP>
  Exit codes: 0 removed or absent, 2 removal failed.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param([string]$VmName = 'arc-hyperv-demo', [switch]$Force)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module Hyper-V
$vm = Get-VM -Name $VmName -ErrorAction SilentlyContinue
if (-not $vm) { Write-Host "VM '$VmName' not present. Nothing to do."; exit 0 }
if ($Force) { $ConfirmPreference = 'None' }
try {
  $disks = (Get-VMHardDiskDrive -VMName $VmName).Path
  if ($PSCmdlet.ShouldProcess($VmName, 'Stop and remove VM and disks')) {
    if ($vm.State -ne 'Off') { Stop-VM -Name $VmName -TurnOff -Force }
    Get-VMSnapshot -VMName $VmName -ErrorAction SilentlyContinue | Remove-VMSnapshot -IncludeAllChildSnapshots -Confirm:$false
    Remove-VM -Name $VmName -Force
    foreach ($d in $disks) { if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Force; Write-Host "Deleted $d" } }
    $vmDir = Split-Path -Parent ($disks | Select-Object -First 1)
    if ($vmDir -and (Test-Path $vmDir) -and -not (Get-ChildItem $vmDir -Recurse -File)) { Remove-Item $vmDir -Recurse -Force }
  }
} catch { Write-Error "Removal failed: $_"; exit 2 }
Write-Host "VM '$VmName' removed." -ForegroundColor Green
if (Get-VM -Name $VmName -ErrorAction SilentlyContinue) { exit 2 } else { exit 0 }
