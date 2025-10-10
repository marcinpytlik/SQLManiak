
param(
  [Parameter(Mandatory=$true)][string]$Domain,
  [Parameter(Mandatory=$true)][string]$GmsaName,            # bez $ na końcu
  [Parameter(Mandatory=$true)][string[]]$Hosts,             # nazwy kont komputerów: NODE1, NODE2 ...
  [Parameter(Mandatory=$true)][string]$HostsGroup,          # np. GRP_SQL_FCI01_GMSA_Hosts
  [Parameter(Mandatory=$true)][string]$OuPath               # np. OU=SQL,DC=sqlmaniak,DC=lab
)

# Require ActiveDirectory module
if (-not (Get-Module -ListAvailable ActiveDirectory)) {
  Write-Host "Installing RSAT-AD-PowerShell..."
  Install-WindowsFeature RSAT-AD-PowerShell -IncludeAllSubFeature -IncludeManagementTools | Out-Null
}
Import-Module ActiveDirectory

# Ensure KDS root key exists
try {
  $kds = Get-KdsRootKey -ErrorAction Stop
  Write-Host "KDS root key exists: $($kds.CreationTime)"
} catch {
  Write-Host "Creating KDS root key (backdated by 10h for immediate availability)..."
  Add-KdsRootKey -EffectiveTime ((Get-Date).AddHours(-10)) | Out-Null
}

# Create hosts group if needed
if (-not (Get-ADGroup -Filter "Name -eq '$HostsGroup'" -ErrorAction SilentlyContinue)) {
  New-ADGroup -Name $HostsGroup -GroupScope Global -GroupCategory Security -Path $OuPath | Out-Null
  Write-Host "Created AD group: $HostsGroup"
} else {
  Write-Host "AD group already exists: $HostsGroup"
}

# Add host computer accounts to the group
$hostComputers = @()
foreach ($h in $Hosts) {
  $cn = if ($h.ToUpper().EndsWith('$')) { $h } else { "$h$" }
  $hostComputers += $cn
}
Add-ADGroupMember -Identity $HostsGroup -Members $hostComputers -ErrorAction SilentlyContinue
Write-Host "Added members to $HostsGroup: $($hostComputers -join ', ')"

# Create gMSA if not exists
$gmsaSam = "$Domain\$GmsaName$"
if (-not (Get-ADServiceAccount -Identity $GmsaName -ErrorAction SilentlyContinue)) {
  New-ADServiceAccount -Name $GmsaName -DNSHostName "$GmsaName.$Domain" -PrincipalsAllowedToRetrieveManagedPassword $HostsGroup | Out-Null
  Write-Host "Created gMSA: $gmsaSam"
} else {
  Write-Host "gMSA already exists: $gmsaSam"
}

Write-Host "DONE. Now run Install-gMSA-OnNodes.ps1 on each node."
