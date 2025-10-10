
param(
  [Parameter(Mandatory=$true)][string]$GmsaName  # bez $ na końcu
)

# Install AD module if needed
if (-not (Get-Module -ListAvailable ActiveDirectory)) {
  Write-Host "Installing RSAT-AD-PowerShell..."
  Install-WindowsFeature RSAT-AD-PowerShell -IncludeAllSubFeature -IncludeManagementTools | Out-Null
}
Import-Module ActiveDirectory

Install-ADServiceAccount -Identity $GmsaName -ErrorAction Stop
if (Test-ADServiceAccount -Identity $GmsaName) {
  Write-Host "gMSA installed & available on this node: $env:COMPUTERNAME -> $GmsaName$"
} else {
  throw "gMSA test failed on $env:COMPUTERNAME"
}

Write-Host "Now use this account during SQL FCI setup: DOMAIN\$GmsaName$ (leave password blank)."
