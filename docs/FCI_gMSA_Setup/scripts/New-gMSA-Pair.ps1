
param(
  [Parameter(Mandatory=$true)][string]$Domain,
  [Parameter(Mandatory=$true)][string]$EngineGmsa,   # bez $ (np. sqlsvc_fci01)
  [Parameter(Mandatory=$true)][string]$AgentGmsa,    # bez $ (np. sqlagt_fci01)
  [Parameter(Mandatory=$true)][string[]]$Hosts,      # np. NODE1,NODE2
  [Parameter(Mandatory=$true)][string]$HostsGroup,   # np. GRP_SQL_FCI01_GMSA_Hosts
  [Parameter(Mandatory=$true)][string]$OuPath        # np. OU=SQL,DC=sqlmaniak,DC=lab
)

if (-not (Get-Module -ListAvailable ActiveDirectory)) {
  Install-WindowsFeature RSAT-AD-PowerShell -IncludeAllSubFeature -IncludeManagementTools | Out-Null
}
Import-Module ActiveDirectory

# KDS root key (jeśli brak)
try { Get-KdsRootKey -ErrorAction Stop | Out-Null }
catch { Add-KdsRootKey -EffectiveTime ((Get-Date).AddHours(-10)) | Out-Null }

# Grupa hostów
if (-not (Get-ADGroup -Filter "Name -eq '$HostsGroup'" -ErrorAction SilentlyContinue)) {
  New-ADGroup -Name $HostsGroup -GroupScope Global -GroupCategory Security -Path $OuPath | Out-Null
}
$hostComputers = foreach($h in $Hosts){ if($h.EndsWith('$')){$h}else{"$h$"} }
Add-ADGroupMember -Identity $HostsGroup -Members $hostComputers -ErrorAction SilentlyContinue

# Engine gMSA
if (-not (Get-ADServiceAccount -Identity $EngineGmsa -ErrorAction SilentlyContinue)) {
  New-ADServiceAccount -Name $EngineGmsa -DNSHostName "$EngineGmsa.$Domain" -PrincipalsAllowedToRetrieveManagedPassword $HostsGroup | Out-Null
}

# Agent gMSA
if (-not (Get-ADServiceAccount -Identity $AgentGmsa -ErrorAction SilentlyContinue)) {
  New-ADServiceAccount -Name $AgentGmsa -DNSHostName "$AgentGmsa.$Domain" -PrincipalsAllowedToRetrieveManagedPassword $HostsGroup | Out-Null
}

Write-Host "Created/validated gMSA accounts: $Domain\$EngineGmsa$, $Domain\$AgentGmsa$"
