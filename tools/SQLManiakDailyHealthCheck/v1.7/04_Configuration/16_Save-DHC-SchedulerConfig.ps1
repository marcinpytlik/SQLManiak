#requires -Version 7.2
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$RepositoryServer,
 [Parameter(Mandatory)][PSCredential]$RepositoryCredential,
 [Parameter(Mandatory)][hashtable]$SqlCredentialByServer,
 [string]$SecretsDirectory=(Join-Path $env:LOCALAPPDATA 'SQLManiakDHC'),
 [switch]$TrustServerCertificate
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(-not $IsWindows){throw 'Windows DPAPI is required.'}
if($SqlCredentialByServer.Count -eq 0){throw 'Source credential map cannot be empty.'}
$root=[IO.Path]::GetFullPath($SecretsDirectory)
$localRoot=[IO.Path]::GetFullPath($env:LOCALAPPDATA).TrimEnd('\')
if(-not $root.StartsWith($localRoot+'\',[StringComparison]::OrdinalIgnoreCase)) {throw 'Secrets must remain in LOCALAPPDATA.'}
if(Test-Path -LiteralPath $root){throw "Directory already exists: $root (no overwrite)."}
[void](New-Item -Path $root -ItemType Directory)
try {
 $RepositoryCredential | Export-Clixml -LiteralPath (Join-Path $root 'repository.xml')
 $targets=[ordered]@{};$i=0
 foreach($key in @($SqlCredentialByServer.Keys | Sort-Object)){
  if([string]::IsNullOrWhiteSpace([string]$key) -or $SqlCredentialByServer[$key] -isnot [PSCredential]){throw 'Invalid target credential.'}
  $i++
  $filename='target-{0:D3}.xml' -f $i
  $SqlCredentialByServer[$key] | Export-Clixml -LiteralPath (Join-Path $root $filename)
  $targets[[string]$key]=$filename
 }
 [ordered]@{Version=1;RepositoryServer=$RepositoryServer;RepositoryCredentialFile='repository.xml';TrustServerCertificate=[bool]$TrustServerCertificate;Targets=$targets} |
 ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $root 'scheduler.json') -Encoding utf8
 Write-Host "Credentials stored with Windows DPAPI under $root" -ForegroundColor Green
 Write-Host 'Restrict the NTFS ACL. The scheduler identity MUST be the same Windows identity and host.'
} catch {Write-Warning 'Setup failed: inspect/delete partial private directory.';throw}
