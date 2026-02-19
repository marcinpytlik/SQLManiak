[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ConfigPath)

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

function Ensure-Folder([string]$Path){ if(-not(Test-Path $Path)){ New-Item -ItemType Directory -Path $Path | Out-Null } }

$config=(Get-Content -Raw -LiteralPath $ConfigPath) | ConvertFrom-Json
if(-not $config.output){ $config | Add-Member output ([pscustomobject]@{}) }
if(-not $config.output.folder){ $config.output | Add-Member folder "C:\temp\SqlInventory" }
Ensure-Folder $config.output.folder

$outPath = Join-Path $config.output.folder "windows-sql-services.csv"

$serviceNameLike = @(
  "MSSQLSERVER", "SQLSERVERAGENT",
  "MSSQL$%", "SQLAgent$%",
  "MsDtsServer%",
  "SQLBrowser",
  "SQLTELEMETRY%",
  "SSASTELEMETRY%", "MSSQLFDLauncher%"
)

$all = New-Object System.Collections.Generic.List[object]

foreach($sv in $config.servers){
  $endpoint=[string]$sv.name
  $alias= if($sv.alias){[string]$sv.alias}else{$endpoint}

  $ComputerName = ($endpoint -split ",")[0]
  

  foreach($pattern in $serviceNameLike){
    try{
      $services = Get-CimInstance -ClassName Win32_Service -ComputerName $ComputerName -Filter "Name LIKE '$pattern'"
      foreach($s in $services){
        $all.Add([pscustomobject]@{
          ServerAlias=$alias
          ServerEndpoint=$endpoint
          WindowsHost=$ComputerName
          ServiceName=$s.Name
          DisplayName=$s.DisplayName
          State=$s.State
          StartMode=$s.StartMode
          StartName=$s.StartName
          PathName=$s.PathName
        }) | Out-Null
      }
    } catch {
      $all.Add([pscustomobject]@{
        ServerAlias=$alias; ServerEndpoint=$endpoint; WindowsHost=$ComputerName
        ServiceName=$pattern; DisplayName=$null; State="ERROR"
        StartMode=$null; StartName=$null; PathName=$null
      }) | Out-Null
    }
  }
}

$all | Sort-Object WindowsHost, ServiceName |
  Export-Csv -LiteralPath $outPath -NoTypeInformation -Encoding UTF8

Write-Host "OK -> $outPath"
