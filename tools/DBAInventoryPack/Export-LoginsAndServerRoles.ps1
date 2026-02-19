[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$ConfigPath
)
. "$PSScriptRoot\SqlInventory.Helpers.ps1"
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Folder([string]$Path){ Ensure-InvFolder -Path $Path }

function Ensure-SqlServerModule(){ Ensure-InvSqlServerModule }

function Add-EncryptParamsCompat([hashtable]$ConnParams,[pscustomobject]$ServerCfg){ Add-InvEncryptParamsCompat -ConnParams $ConnParams -ServerCfg $ServerCfg }

function New-ConnParamsFromConfig($ServerCfg,$RootCfg){ New-InvSqlConnParams -ServerCfg $ServerCfg -Config $RootCfg -Database 'master' }

# ---------------- MAIN ----------------
Ensure-SqlServerModule

if(-not (Test-Path -LiteralPath $ConfigPath)){
  throw "Nie znaleziono configu: $ConfigPath"
}

$config = (Get-Content -Raw -LiteralPath $ConfigPath) | ConvertFrom-Json

# Defaults (bez dopisywania property, strict-friendly)
$outFolder = "C:\temp\SqlInventory"
if ($config.output -and $config.output.folder) { $outFolder = [string]$config.output.folder }
Ensure-Folder $outFolder

$outPath = Join-Path $outFolder "sql-logins-serverroles.csv"

$query = @"
SET NOCOUNT ON;

;WITH Roles AS (
  SELECT
    m.member_principal_id,
    ServerRoles = STRING_AGG(r.name, '; ') WITHIN GROUP (ORDER BY r.name)
  FROM sys.server_role_members m
  JOIN sys.server_principals r ON r.principal_id = m.role_principal_id
  GROUP BY m.member_principal_id
)
SELECT
  @@SERVERNAME AS SqlServerName,
  sp.name AS LoginName,
  sp.type_desc AS LoginType,
  sp.is_disabled AS IsDisabled,
  sp.default_database_name AS DefaultDatabase,
  sp.default_language_name AS DefaultLanguage,
  sp.create_date AS CreateDate,
  sp.modify_date AS ModifyDate,
  ISNULL(r.ServerRoles,'') AS ServerRoles,
  CASE WHEN IS_SRVROLEMEMBER('sysadmin', sp.name) = 1 THEN 1 ELSE 0 END AS IsSysadmin,
  sl.is_policy_checked AS IsPolicyChecked,
  sl.is_expiration_checked AS IsExpirationChecked
FROM sys.server_principals sp
LEFT JOIN sys.sql_logins sl ON sl.principal_id = sp.principal_id
LEFT JOIN Roles r ON r.member_principal_id = sp.principal_id
WHERE sp.type IN ('S','U','G')
  AND sp.name NOT LIKE '##%##'
ORDER BY sp.name;
"@

$all = New-Object System.Collections.Generic.List[object]

foreach($sv in $config.servers){
  $endpoint = [string]$sv.name
  $alias = if($sv.alias){[string]$sv.alias}else{$endpoint}

  Write-Host ("==> [{0}] Logins+roles..." -f $endpoint)

  try{
    $conn = New-ConnParamsFromConfig -ServerCfg $sv -RootCfg $config
    $rows = Invoke-Sqlcmd @conn -Query $query

    foreach($r in $rows){
      $all.Add([pscustomobject]@{
        ServerAlias=$alias
        ServerEndpoint=$endpoint
        SqlServerName=$r.SqlServerName

        LoginName=$r.LoginName
        LoginType=$r.LoginType
        IsDisabled=$r.IsDisabled
        DefaultDatabase=$r.DefaultDatabase
        DefaultLanguage=$r.DefaultLanguage
        CreateDate=$r.CreateDate
        ModifyDate=$r.ModifyDate
        ServerRoles=$r.ServerRoles
        IsSysadmin=$r.IsSysadmin
        IsPolicyChecked=$r.IsPolicyChecked
        IsExpirationChecked=$r.IsExpirationChecked
      }) | Out-Null
    }

    Write-Host ("    OK: {0} loginów" -f ($rows.Count))
  }
  catch{
    Write-Warning ("Błąd {0}: {1}" -f $endpoint, $_.Exception.Message)
  }
}

# Sort: sysadmin na górze, potem serwer, potem login
$all |
  Sort-Object `
    @{ Expression = 'IsSysadmin'; Descending = $true }, `
    'ServerAlias', `
    'LoginName' |
  Export-Csv -LiteralPath $outPath -NoTypeInformation -Encoding UTF8

Write-Host ("OK -> {0}" -f $outPath)