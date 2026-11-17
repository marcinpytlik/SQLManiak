#requires -Version 7.2
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$ConfigPath,
 [ValidateSet('PROD','TEST','DEV','LAB','DR')][string]$Environment='LAB',
 [switch]$Execute,
 [ValidateRange(1,300)][int]$ConnectionTimeout=5,
 [ValidateRange(1,3600)][int]$QueryTimeout=300
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(-not $IsWindows){throw 'Windows DPAPI is required.'}
Import-Module SqlServer -ErrorAction Stop
Add-Type -AssemblyName Microsoft.Data.SqlClient -ErrorAction Stop
$cfg=Get-Content -LiteralPath $ConfigPath -Raw -Encoding utf8 | ConvertFrom-Json
if($cfg.Version -ne 1){throw 'Unknown config version.'}
$dir=Split-Path -Parent ([IO.Path]::GetFullPath($ConfigPath))
function Read-Cred([string]$name){
 if([string]::IsNullOrWhiteSpace($name) -or [IO.Path]::IsPathRooted($name) -or [IO.Path]::GetFileName($name) -ne $name){throw 'Invalid secret filename.'}
 $x=Import-Clixml -LiteralPath (Join-Path $dir $name)
 if($x -isnot [PSCredential]){throw 'Credential import failed.'}
 return $x
}
$repo=Read-Cred ([string]$cfg.RepositoryCredentialFile)
$b=[Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new()
# Use canonical SqlClient connection-string keywords via the indexer.
# PowerShell's IDictionary adapter can otherwise interpret .DataSource as an
# unsupported literal "DataSource" keyword instead of "Data Source".
$b['Data Source']=[string]$cfg.RepositoryServer
$b['Initial Catalog']='SQLManiakHealthHistory'
$b['User ID']=$repo.UserName
$b['Password']=$repo.GetNetworkCredential().Password
$b['Encrypt']='True'
$b['Trust Server Certificate']=[bool]$cfg.TrustServerCertificate
$b['Connect Timeout']=$ConnectionTimeout
$b['Persist Security Info']=$false
$credentials=@{}
foreach($entry in $cfg.Targets.PSObject.Properties) {
 $credentials[[string]$entry.Name]=Read-Cred ([string]$entry.Value)
}
try {
 $runner=Join-Path $PSScriptRoot '06_Run-DHC-MonitoredServers.ps1'
 $results=@(& $runner -RepositoryConnectionString $b.ConnectionString `
   -SqlCredentialByServer $credentials -Environment $Environment -Execute:$Execute `
   -TrustServerCertificate:([bool]$cfg.TrustServerCertificate) `
   -ConnectionTimeout $ConnectionTimeout -QueryTimeout $QueryTimeout)
 foreach($result in $results){$result}
 if($Execute -and @($results | Where-Object { $_.Status -eq 'FAILED' }).Count -gt 0) {throw 'At least one source FAILED. Check dhc.ExecutionLog.'}
}
finally {$b.Clear();$credentials.Clear();$repo=$null}
