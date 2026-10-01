<#
.SYNOPSIS
  Preflight for the Hyper-V host (Windows 11 Pro/Enterprise/Education or Windows Server).
.DESCRIPTION
  Checks edition, Hyper-V feature state, admin rights, hardware virtualization, memory, disk,
  virtual switch, ISO/image path, PowerShell version, DNS and outbound HTTPS, and hypervisor conflicts.
  Exit code 0 = all required checks pass; 1 = at least one required check failed.
.EXAMPLE
  .\Test-HyperVPrerequisites.ps1 -SwitchName 'Default Switch' -MediaPath 'C:\ISO\ubuntu-24.04.3-live-server-amd64.iso' -VmPath 'C:\HyperV\arc-hyperv-demo'
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$SwitchName,
  [Parameter(Mandatory)][string]$MediaPath,
  [Parameter(Mandatory)][string]$VmPath,
  [int]$RequiredFreeMemoryGB = 6,
  [int]$RequiredFreeDiskGB   = 45
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Failed = $false
function Pass([string]$m){ Write-Host "  [PASS] $m" -ForegroundColor Green }
function Warn([string]$m){ Write-Host "  [WARN] $m" -ForegroundColor Yellow }
function Fail([string]$m){ Write-Host "  [FAIL] $m" -ForegroundColor Red; $script:Failed = $true }

Write-Host "== Hyper-V host preflight ==" -ForegroundColor Cyan

# Admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) { Pass 'Running elevated' } else { Fail 'Not elevated. Run PowerShell as Administrator.' }

# PowerShell version (Hyper-V module works in Windows PowerShell 5.1 and PowerShell 7 on Windows)
if ($PSVersionTable.PSVersion.Major -ge 5) { Pass "PowerShell $($PSVersionTable.PSVersion)" } else { Fail 'PowerShell 5.1 or later required' }

# Edition
$os = Get-CimInstance Win32_OperatingSystem
if ($os.Caption -match 'Home') { Fail "$($os.Caption) does not include Hyper-V. Use Pro/Enterprise/Education or Windows Server." } else { Pass "Edition: $($os.Caption)" }

# Hyper-V feature (client) or role (server)
try {
  $feat = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction Stop
  if ($feat.State -eq 'Enabled') { Pass 'Hyper-V feature enabled' }
  else { Fail 'Hyper-V feature disabled. Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All (reboot required)' }
} catch { Warn "Could not query optional feature ($_). On Windows Server use Get-WindowsFeature Hyper-V." }

if (Get-Module -ListAvailable -Name Hyper-V) { Pass 'Hyper-V PowerShell module available' } else { Fail 'Hyper-V PowerShell module missing (Hyper-V Management Tools)' }

# Hardware virtualization (reported only when the hypervisor is NOT already running)
$cs = Get-CimInstance Win32_ComputerSystem
if ($cs.HypervisorPresent) { Pass 'Hypervisor present (Hyper-V running)' }
else {
  $ci = Get-ComputerInfo -Property HyperVRequirement*
  if ($ci.HyperVRequirementVirtualizationFirmwareEnabled -and $ci.HyperVRequirementSecondLevelAddressTranslation -and $ci.HyperVRequirementVMMonitorModeExtensions) { Pass 'Hardware virtualization, SLAT and VMX available' }
  else { Fail 'Hardware virtualization not fully available. Enable VT-x/AMD-V in firmware.' }
}

# Conflicting hypervisors (modern VirtualBox/VMware can coexist via Windows Hypervisor Platform, but performance and networking can suffer)
foreach ($svc in 'VBoxSDS','VMwareHostd','VMAuthdService') { if (Get-Service -Name $svc -ErrorAction SilentlyContinue) { Warn "Other hypervisor service present: $svc (coexistence works via WHP but may reduce reliability)" } }

# Memory
$freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
if ($freeGB -ge $RequiredFreeMemoryGB) { Pass "Free memory ${freeGB} GB (need $RequiredFreeMemoryGB)" } else { Fail "Free memory ${freeGB} GB < $RequiredFreeMemoryGB GB" }

# Disk
$drive = (Resolve-Path (Split-Path -Qualifier $VmPath)).Path
$freeDiskGB = [math]::Round((Get-PSDrive -Name $drive.TrimEnd(':\')).Free / 1GB, 1)
if ($freeDiskGB -ge $RequiredFreeDiskGB) { Pass "Free disk on ${drive} ${freeDiskGB} GB (need $RequiredFreeDiskGB)" } else { Fail "Free disk ${freeDiskGB} GB < $RequiredFreeDiskGB GB" }

# Virtual switch
$sw = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
if ($sw) { Pass "Virtual switch '$SwitchName' ($($sw.SwitchType))" } else { Fail "Virtual switch '$SwitchName' not found. Get-VMSwitch to list; 'Default Switch' provides NAT+DHCP on Windows client." }

# Media
if (Test-Path -LiteralPath $MediaPath) { Pass "Media found: $MediaPath" } else { Fail "Media not found: $MediaPath" }

# DNS + outbound HTTPS to Arc endpoints
foreach ($h in 'login.microsoftonline.com','management.azure.com','packages.microsoft.com','gbl.his.arc.azure.com') {
  try { $null = Resolve-DnsName $h -ErrorAction Stop; Pass "DNS resolves $h" } catch { Fail "DNS cannot resolve $h" }
}
foreach ($h in 'login.microsoftonline.com','management.azure.com') {
  $t = Test-NetConnection -ComputerName $h -Port 443 -WarningAction SilentlyContinue
  if ($t.TcpTestSucceeded) { Pass "TCP 443 to $h" } else { Fail "No TCP 443 to $h" }
}

Write-Host ''
if ($script:Failed) { Write-Host 'PREFLIGHT FAIL' -ForegroundColor Red; exit 1 } else { Write-Host 'PREFLIGHT PASS' -ForegroundColor Green; exit 0 }
