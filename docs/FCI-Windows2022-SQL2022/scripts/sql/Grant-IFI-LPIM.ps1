<#
.SYNOPSIS
  Nadaje uprawnienia systemowe dla konta usługi SQL: 
  - IFI: Perform volume maintenance tasks (SeManageVolumePrivilege)
  - LPIM: Lock pages in memory (SeLockMemoryPrivilege)
  Działa lokalnie, bez dodatkowych modułów – używa secedit.

.EXAMPLE
  .\Grant-IFI-LPIM.ps1 -Account 'sqlmaniak\gmsa_sql$'
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Account
)
$ErrorActionPreference='Stop'

function Get-SidString([string]$acct){
  try {
    $sid = (New-Object System.Security.Principal.NTAccount($acct)).Translate([System.Security.Principal.SecurityIdentifier]).Value
    return $sid
  } catch {
    throw "Nie mogę przetłumaczyć konta '$acct' na SID. Czy istnieje lokalnie/domenowo?"
  }
}

$acctSid = Get-SidString -acct $Account
$starSid = "*$acctSid"

# 1) Eksport aktualnej polityki
$tmp = Join-Path $env:TEMP ("secedit_{0:yyyyMMdd_HHmmss}.inf" -f (Get-Date))
secedit /export /cfg "$tmp" | Out-Null

# 2) Wczytaj sekcję [Privilege Rights]
$lines = Get-Content $tmp
$start = ($lines | Select-String -SimpleMatch "[Privilege Rights]").LineNumber
if (-not $start) { throw "Nie znaleziono sekcji [Privilege Rights] w eksporcie secedit." }
$privLines = $lines[$start..($lines.Length-1)]

function Parse-Right($name){
  $l = $privLines | Where-Object { $_ -match "^\s*$name\s*=" } | Select-Object -First 1
  if ($null -eq $l) { return @() }
  $vals = ($l -split "=",2)[1].Trim()
  if ([string]::IsNullOrEmpty($vals)) { return @() }
  return ($vals -split ",").ForEach({ $_.Trim() }) | Where-Object { $_ -ne "" }
}

$seManage = Parse-Right "SeManageVolumePrivilege"
$seLock   = Parse-Right "SeLockMemoryPrivilege"

# 3) Dodaj SID jeśli nie istnieje
if ($seManage -notcontains $starSid) { $seManage += $starSid }
if ($seLock   -notcontains $starSid) { $seLock   += $starSid }

# 4) Zbuduj minimalny INF z uaktualnionymi dwoma prawami
$minInf = @"
[Unicode]
Unicode=yes
[Version]
signature="$CHICAGO$"
Revision=1
[Privilege Rights]
SeManageVolumePrivilege = {SEMANAGE}
SeLockMemoryPrivilege   = {SELOCK}
"@

$minInf = $minInf.Replace("{SEMANAGE}", ($seManage -join ","))
$minInf = $minInf.Replace("{SELOCK}",   ($seLock   -join ","))

$cfg = Join-Path $env:TEMP ("GrantRights_{0:yyyyMMdd_HHmmss}.inf" -f (Get-Date))
Set-Content -Path $cfg -Value $minInf -Encoding Unicode

# 5) Załaduj zmiany (tylko USER_RIGHTS)
secedit /configure /db "$env:windir\security\local.sdb" /cfg "$cfg" /areas USER_RIGHTS | Out-Null

Write-Host "Nadano uprawnienia IFI/LPIM dla: $Account ($acctSid)" -ForegroundColor Green
Write-Host "Zmiany obowiązują po restarcie usługi SQL (IFI) / ponownym logowaniu konta (LPIM)."
