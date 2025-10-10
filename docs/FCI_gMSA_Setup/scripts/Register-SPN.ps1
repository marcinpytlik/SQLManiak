
param(
  [Parameter(Mandatory=$true)][string]$Domain,
  [Parameter(Mandatory=$true)][string]$GmsaName,    # gMSA silnika (bez $)
  [Parameter(Mandatory=$true)][string]$VnnFqdn,     # np. SQLPROD.sqlmaniak.lab
  [Parameter(Mandatory=$false)][int]$Port = 1433,
  [Parameter(Mandatory=$false)][string]$AgListenerFqdn # opcjonalnie
)

$acct = "$Domain\$GmsaName$"
Write-Host "Registering SPN for VNN: $VnnFqdn on $acct"
& setspn.exe -S "MSSQLSvc/$VnnFqdn" $acct | Out-Null
& setspn.exe -S "MSSQLSvc/$VnnFqdn:$Port" $acct | Out-Null

if ($AgListenerFqdn) {
  Write-Host "Registering SPN for AG Listener: $AgListenerFqdn on $acct"
  & setspn.exe -S "MSSQLSvc/$AgListenerFqdn" $acct | Out-Null
  & setspn.exe -S "MSSQLSvc/$AgListenerFqdn:$Port" $acct | Out-Null
}

Write-Host "SPN registered successfully for: $acct"
