[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$ConfigPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

# Helper (po param!)
. "$PSScriptRoot\SqlInventory.Helpers.ps1"

$config = Import-InvConfig -ConfigPath $ConfigPath
$outPath = Get-InvOutputPath -Config $config -DefaultFileName "windows-sql-services.csv"

$serviceNameLike = @(
  "MSSQLSERVER", "SQLSERVERAGENT",
  "MSSQL$%", "SQLAgent$%",
  "MsDtsServer%",
  "SQLBrowser",
  "SQLTELEMETRY%",
  "SSASTELEMETRY%", "MSSQLFDLauncher%"
)

# MUSI być zawsze zainicjalizowane (StrictMode)
$all = New-Object System.Collections.Generic.List[object]

foreach($sv in $config.servers){
  $endpoint = [string]$sv.name
  $alias = if($sv.alias){[string]$sv.alias}else{$endpoint}

  # host Windows = część przed przecinkiem (port SQL ignorujemy)
  $ComputerName = ($endpoint -split ",")[0].Trim()

  foreach($pattern in $serviceNameLike){
    try{
      $services = Get-CimInstance -ClassName Win32_Service -ComputerName $ComputerName -Filter "Name LIKE '$pattern'" -ErrorAction Stop
      foreach($s in $services){
        $all.Add([pscustomobject]@{
          ServerAlias   = $alias
          ServerEndpoint= $endpoint
          WindowsHost   = $ComputerName
          ServiceName   = $s.Name
          DisplayName   = $s.DisplayName
          State         = $s.State
          StartMode     = $s.StartMode
          StartName     = $s.StartName
          PathName      = $s.PathName
        }) | Out-Null
      }
    }
    catch{
      # Zapisz jako ERROR, ale nie wywalaj całego skryptu
      $all.Add([pscustomobject]@{
        ServerAlias   = $alias
        ServerEndpoint= $endpoint
        WindowsHost   = $ComputerName
        ServiceName   = $pattern
        DisplayName   = $null
        State         = "ERROR"
        StartMode     = $null
        StartName     = $null
        PathName      = $null
      }) | Out-Null
    }
  }
}

$all |
  Sort-Object WindowsHost, ServiceName |
  Export-Csv -LiteralPath $outPath -NoTypeInformation -Encoding UTF8

Write-Host ("OK -> {0}" -f $outPath)