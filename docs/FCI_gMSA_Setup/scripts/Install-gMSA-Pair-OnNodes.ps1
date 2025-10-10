
param(
  [Parameter(Mandatory=$true)][string]$EngineGmsa,
  [Parameter(Mandatory=$true)][string]$AgentGmsa
)

if (-not (Get-Module -ListAvailable ActiveDirectory)) {
  Install-WindowsFeature RSAT-AD-PowerShell -IncludeAllSubFeature -IncludeManagementTools | Out-Null
}
Import-Module ActiveDirectory

Install-ADServiceAccount -Identity $EngineGmsa -ErrorAction SilentlyContinue | Out-Null
Install-ADServiceAccount -Identity $AgentGmsa  -ErrorAction SilentlyContinue | Out-Null

$e = Test-ADServiceAccount -Identity $EngineGmsa
$a = Test-ADServiceAccount -Identity $AgentGmsa

if($e -and $a){
  Write-Host "gMSA available on $env:COMPUTERNAME: $EngineGmsa$, $AgentGmsa$"
} else {
  throw "gMSA test failed (Engine=$e, Agent=$a) on $env:COMPUTERNAME"
}
