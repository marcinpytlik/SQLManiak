<#
SqlInventory.Helpers.ps1
Wspólne helpery dla DBAInventoryPack (PowerShell 5.1+/7+).
Cel: jedna, spójna obsługa config.json, output, Invoke-Sqlcmd, Encrypt/TrustServerCertificate i drobnych pułapek parsera.

Użycie w skryptach:
  . "$PSScriptRoot\SqlInventory.Helpers.ps1"
  $cfg = Import-InvConfig -ConfigPath $ConfigPath
  Ensure-InvSqlServerModule
  $conn = New-InvSqlConnParams -ServerCfg $sv -Config $cfg -Database 'master'
  $rows = Invoke-Sqlcmd @conn -Query $query
#>

Set-StrictMode -Version Latest

function Import-InvConfig {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$ConfigPath)

  if(-not (Test-Path -LiteralPath $ConfigPath)){
    throw "Nie znaleziono configu: $ConfigPath"
  }

  $cfg = (Get-Content -LiteralPath $ConfigPath -Raw) | ConvertFrom-Json

  # Defaults (bez dopisywania property - strict-friendly)
  if(-not $cfg.auth){ $cfg | Add-Member -NotePropertyName auth -NotePropertyValue ([pscustomobject]@{ mode = "Windows" }) }
  if(-not $cfg.auth.mode){ $cfg.auth | Add-Member -NotePropertyName mode -NotePropertyValue "Windows" }

  if(-not $cfg.options){ $cfg | Add-Member -NotePropertyName options -NotePropertyValue ([pscustomobject]@{}) }
  if(-not ($cfg.options.PSObject.Properties.Name -contains "commandTimeoutSeconds")){
    $cfg.options | Add-Member -NotePropertyName commandTimeoutSeconds -NotePropertyValue 60
  }
  if(-not ($cfg.options.PSObject.Properties.Name -contains "includeSystemDbs")){
    $cfg.options | Add-Member -NotePropertyName includeSystemDbs -NotePropertyValue $true
  }

  if(-not $cfg.output){ $cfg | Add-Member -NotePropertyName output -NotePropertyValue ([pscustomobject]@{}) }
  if(-not ($cfg.output.PSObject.Properties.Name -contains "folder")){
    $cfg.output | Add-Member -NotePropertyName folder -NotePropertyValue "C:\temp\SqlInventory"
  }

  if(-not $cfg.servers){ throw "Brak sekcji servers w config.json" }

  return $cfg
}

function Ensure-InvFolder {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$Path)
  if(-not (Test-Path -LiteralPath $Path)){
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Ensure-InvSqlServerModule {
  [CmdletBinding()]
  param()
  if(-not (Get-Module -ListAvailable -Name SqlServer)){
    throw "Brak modułu 'SqlServer'. Zainstaluj: Install-Module SqlServer -Scope CurrentUser"
  }
}

function Get-InvOutputFolder {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][pscustomobject]$Config)

  $folder = "C:\temp\SqlInventory"
  if($Config.output -and ($Config.output.PSObject.Properties.Name -contains "folder") -and $Config.output.folder){
    $folder = [string]$Config.output.folder
  }
  Ensure-InvFolder -Path $folder
  return $folder
}

function Get-InvOutputPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][pscustomobject]$Config,
    [Parameter(Mandatory=$true)][string]$DefaultFileName,
    [Parameter()][string]$ConfigOutputPropertyName
  )

  $folder = Get-InvOutputFolder -Config $Config
  $fileName = $DefaultFileName

  if($ConfigOutputPropertyName){
    if($Config.output -and ($Config.output.PSObject.Properties.Name -contains $ConfigOutputPropertyName)){
      $val = $Config.output.$ConfigOutputPropertyName
      if($val){ $fileName = [string]$val }
    }
  }

  return (Join-Path $folder $fileName)
}

function Add-InvEncryptParamsCompat {
  <#
    Invoke-Sqlcmd ma różne interfejsy zależnie od wersji modułu SqlServer:
    -Encrypt bywa bool albo ValidateSet: Mandatory|Optional|Strict
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][hashtable]$ConnParams,
    [Parameter(Mandatory=$true)][pscustomobject]$ServerCfg
  )

  $invoke = Get-Command Invoke-Sqlcmd -ErrorAction Stop

  $encryptParam = $invoke.Parameters['Encrypt']
  if($encryptParam -and $null -ne $ServerCfg.encrypt){
    $encryptRaw = $ServerCfg.encrypt

    $validateSet = $encryptParam.Attributes |
      Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
      Select-Object -First 1

    if($validateSet){
      # Mandatory|Optional|Strict
      if($encryptRaw -is [string]){ $ConnParams.Encrypt = $encryptRaw }
      else { $ConnParams.Encrypt = "Optional" }
    } else {
      # bool
      $ConnParams.Encrypt = [bool]$encryptRaw
    }
  }

  $tscParam = $invoke.Parameters['TrustServerCertificate']
  if($tscParam -and $null -ne $ServerCfg.trustServerCertificate){
    $ConnParams.TrustServerCertificate = [bool]$ServerCfg.trustServerCertificate
  }
}

function New-InvSqlConnParams {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][pscustomobject]$ServerCfg,
    [Parameter(Mandatory=$true)][pscustomobject]$Config,
    [Parameter()][string]$Database = "master"
  )

  $timeout = 60
  if($Config.options -and $Config.options.commandTimeoutSeconds){
    $timeout = [int]$Config.options.commandTimeoutSeconds
  }

  $p = @{
    ServerInstance = [string]$ServerCfg.name
    Database       = $Database
    QueryTimeout   = $timeout
    ErrorAction    = "Stop"
  }

  switch($Config.auth.mode){
    "Windows" { }
    "SqlLogin" {
      if(-not $Config.auth.user -or -not $Config.auth.password){
        throw "auth.mode=SqlLogin wymaga auth.user i auth.password."
      }
      $sec = ConvertTo-SecureString $Config.auth.password -AsPlainText -Force
      $p.Username = [string]$Config.auth.user
      $p.Password = $sec
    }
    default { throw "Nieznany auth.mode: $($Config.auth.mode). Użyj Windows albo SqlLogin." }
  }

  Add-InvEncryptParamsCompat -ConnParams $p -ServerCfg $ServerCfg
  return $p
}

function Write-InvWarning {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$Context,
    [Parameter(Mandatory=$true)][string]$Message
  )
  # bez pułapek typu "$var:"
  Write-Warning ("{0}: {1}" -f $Context, $Message)
}
