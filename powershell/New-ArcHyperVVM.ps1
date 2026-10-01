<#
.SYNOPSIS
  Create the local Generation 2 Ubuntu VM 'arc-hyperv-demo' on Hyper-V.
.DESCRIPTION
  Path A (default): attach the Ubuntu Server ISO; the OS install is interactive (see docs/instructor-runbook.md).
  Path B (-UseBaseVhdx): copy a prepared Ubuntu VHDX (cloud image converted with qemu-img) and attach a NoCloud 'cidata' ISO.
  Idempotent: exits 0 if a VM with the same name already exists and is running.
  Exit codes: 0 ok, 1 prerequisite/input error, 2 creation failed.
.EXAMPLE
  .\New-ArcHyperVVM.ps1 -SwitchName 'Default Switch' -IsoPath 'C:\ISO\ubuntu-24.04.3-live-server-amd64.iso' -VmPath 'C:\HyperV'
.EXAMPLE
  .\New-ArcHyperVVM.ps1 -SwitchName 'Default Switch' -VmPath 'C:\HyperV' -UseBaseVhdx -BaseVhdxPath 'C:\Images\ubuntu-24.04-cloudimg.vhdx' -CidataIsoPath 'C:\Images\cidata.iso'
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$VmName = 'arc-hyperv-demo',
  [Parameter(Mandatory)][string]$SwitchName,
  [Parameter(Mandatory)][string]$VmPath,
  [string]$IsoPath,
  [switch]$UseBaseVhdx,
  [string]$BaseVhdxPath,
  [string]$CidataIsoPath,
  [int]$ProcessorCount = 2,
  [long]$StartupMemoryBytes = 4GB,
  [long]$MinimumMemoryBytes = 2GB,
  [long]$MaximumMemoryBytes = 6GB,
  [long]$DiskSizeBytes = 40GB
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name Hyper-V)) { Write-Error 'Hyper-V module not available'; exit 1 }
Import-Module Hyper-V
if (-not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) { Write-Error "Switch '$SwitchName' not found"; exit 1 }
if ($UseBaseVhdx) {
  if (-not $BaseVhdxPath -or -not (Test-Path -LiteralPath $BaseVhdxPath)) { Write-Error 'Path B requires -BaseVhdxPath to an existing VHDX'; exit 1 }
  if (-not $CidataIsoPath -or -not (Test-Path -LiteralPath $CidataIsoPath)) { Write-Error 'Path B requires -CidataIsoPath (NoCloud seed ISO)'; exit 1 }
} else {
  if (-not $IsoPath -or -not (Test-Path -LiteralPath $IsoPath)) { Write-Error 'Path A requires -IsoPath to the Ubuntu Server ISO'; exit 1 }
}

$existing = Get-VM -Name $VmName -ErrorAction SilentlyContinue
if ($existing) {
  Write-Host "VM '$VmName' already exists (State: $($existing.State))."
  if ($existing.State -ne 'Running' -and $PSCmdlet.ShouldProcess($VmName,'Start-VM')) { Start-VM -Name $VmName }
  exit 0
}

$vmDir   = Join-Path $VmPath $VmName
$vhdPath = Join-Path $vmDir "$VmName.vhdx"
New-Item -ItemType Directory -Path $vmDir -Force | Out-Null

try {
  if ($PSCmdlet.ShouldProcess($VmName, 'Create Generation 2 VM')) {
    if ($UseBaseVhdx) {
      Copy-Item -LiteralPath $BaseVhdxPath -Destination $vhdPath
      Resize-VHD -Path $vhdPath -SizeBytes $DiskSizeBytes   # cloud-init growpart expands the root FS on first boot
      $vm = New-VM -Name $VmName -Generation 2 -MemoryStartupBytes $StartupMemoryBytes -VHDPath $vhdPath -SwitchName $SwitchName -Path $VmPath
      Add-VMDvdDrive -VMName $VmName -Path $CidataIsoPath
    } else {
      $vm = New-VM -Name $VmName -Generation 2 -MemoryStartupBytes $StartupMemoryBytes -NewVHDPath $vhdPath -NewVHDSizeBytes $DiskSizeBytes -SwitchName $SwitchName -Path $VmPath
      Add-VMDvdDrive -VMName $VmName -Path $IsoPath
    }

    Set-VMProcessor -VMName $VmName -Count $ProcessorCount
    Set-VMMemory   -VMName $VmName -DynamicMemoryEnabled $true -MinimumBytes $MinimumMemoryBytes -StartupBytes $StartupMemoryBytes -MaximumBytes $MaximumMemoryBytes
    # Linux Secure Boot requires the Microsoft UEFI CA template (not the Windows template).
    Set-VMFirmware -VMName $VmName -EnableSecureBoot On -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'
    $dvd = Get-VMDvdDrive -VMName $VmName
    Set-VMFirmware -VMName $VmName -FirstBootDevice $(if ($UseBaseVhdx) { Get-VMHardDiskDrive -VMName $VmName } else { $dvd })
    Set-VM -Name $VmName -AutomaticCheckpointsEnabled $false -CheckpointType Standard -AutomaticStartAction Nothing -AutomaticStopAction ShutDown
    Enable-VMIntegrationService -VMName $VmName -Name 'Time Synchronization','Heartbeat','Key-Value Pair Exchange','Shutdown'
    Start-VM -Name $VmName
  }
} catch {
  Write-Error "VM creation failed: $_"; exit 2
}

Write-Host "VM '$VmName' created and started." -ForegroundColor Green
Get-VM -Name $VmName | Format-List Name, State, Generation, ProcessorCount, MemoryStartup, Path
if (-not $UseBaseVhdx) {
  Write-Host "Path A: complete the Ubuntu Server install in the console (vmconnect localhost $VmName)." -ForegroundColor Yellow
  Write-Host '        Choose: minimal install, OpenSSH server optional, hostname arc-hyperv-demo. Then run scripts/configure-demo-service.sh.' -ForegroundColor Yellow
}
