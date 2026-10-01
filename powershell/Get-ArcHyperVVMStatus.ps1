<#
.SYNOPSIS  Report VM state, heartbeat, and guest IP addresses for arc-hyperv-demo.
.DESCRIPTION
  IP discovery relies on the Key-Value Pair integration service and the guest's hv_kvp_daemon
  (package linux-cloud-tools-virtual on Ubuntu). Without it, IPAddresses is empty and you must use the console.
  Exit codes: 0 running, 1 not found, 2 not running.
#>
[CmdletBinding()]
param([string]$VmName = 'arc-hyperv-demo', [int]$WaitForIpSeconds = 0)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module Hyper-V
$vm = Get-VM -Name $VmName -ErrorAction SilentlyContinue
if (-not $vm) { Write-Error "VM '$VmName' not found"; exit 1 }
$vm | Format-List Name, State, Status, Heartbeat, Uptime, CPUUsage, MemoryAssigned, Generation
$deadline = (Get-Date).AddSeconds($WaitForIpSeconds)
do {
  $ips = (Get-VMNetworkAdapter -VMName $VmName).IPAddresses | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' }
  if ($ips) { break }
  if ($WaitForIpSeconds -gt 0) { Start-Sleep -Seconds 5 }
} while ((Get-Date) -lt $deadline)
if ($ips) { Write-Host "Guest IPv4: $($ips -join ', ')" } else { Write-Warning 'No IPv4 reported yet (guest KVP daemon not running or still booting). Use the VM console.' }
(Get-VMFirmware -VMName $VmName) | Format-List SecureBoot, SecureBootTemplate
if ($vm.State -eq 'Running') { exit 0 } else { exit 2 }
