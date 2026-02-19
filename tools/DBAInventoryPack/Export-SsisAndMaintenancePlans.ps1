[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ConfigPath)

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

function Ensure-Folder([string]$Path){ if(-not(Test-Path $Path)){ New-Item -ItemType Directory -Path $Path | Out-Null } }
function Ensure-SqlServerModule(){ if(-not(Get-Module -ListAvailable -Name SqlServer)){ throw "Brak modułu SqlServer. Install-Module SqlServer -Scope CurrentUser" } }
function New-ConnParamsFromConfig($ServerCfg,$RootCfg){
  $p=@{ ServerInstance=[string]$ServerCfg.name; Database="msdb"; QueryTimeout=[int]$RootCfg.options.commandTimeoutSeconds; ErrorAction="Stop" }
  if($null -ne $ServerCfg.encrypt){ $p.Encrypt=[bool]$ServerCfg.encrypt }
  if($null -ne $ServerCfg.trustServerCertificate){ $p.TrustServerCertificate=[bool]$ServerCfg.trustServerCertificate }
  switch($RootCfg.auth.mode){
    "Windows" { }
    "SqlLogin" {
      $sec=ConvertTo-SecureString $RootCfg.auth.password -AsPlainText -Force
      $p.Username=[string]$RootCfg.auth.user; $p.Password=$sec
    }
    default { throw "Nieznany auth.mode: $($RootCfg.auth.mode)" }
  }
  $p
}

Ensure-SqlServerModule
$config=(Get-Content -Raw -LiteralPath $ConfigPath) | ConvertFrom-Json
if(-not $config.options){ $config | Add-Member options ([pscustomobject]@{}) }
if($null -eq $config.options.commandTimeoutSeconds){ $config.options | Add-Member commandTimeoutSeconds 60 }
if(-not $config.output){ $config | Add-Member output ([pscustomobject]@{}) }
if(-not $config.output.folder){ $config.output | Add-Member folder "C:\temp\SqlInventory" }
Ensure-Folder $config.output.folder

$outMP = Join-Path $config.output.folder "sql-maintenance-plans.csv"
$outSS = Join-Path $config.output.folder "sql-ssis-packages-msdb.csv"

$qMP=@"
SET NOCOUNT ON;
SELECT
  @@SERVERNAME AS SqlServerName,
  p.id AS PlanId,
  p.name AS PlanName,
  p.description AS Description,
  SUSER_SNAME(p.owner_sid) AS OwnerLogin,
  p.createdate AS CreateDate,
  p.modifieddate AS ModifyDate
FROM msdb.dbo.sysmaintplan_plans p
ORDER BY p.name;
"@

$qSS=@"
SET NOCOUNT ON;

IF OBJECT_ID('msdb.dbo.sysssispackages') IS NULL
BEGIN
  SELECT @@SERVERNAME AS SqlServerName,
         CAST(NULL AS uniqueidentifier) AS PackageId,
         CAST(NULL AS sysname) AS PackageName,
         CAST(NULL AS sysname) AS Folder,
         CAST(NULL AS datetime) AS CreatedDate,
         CAST(NULL AS datetime) AS LastModifiedDate,
         CAST('INFO:sysssispackages_not_present' AS varchar(200)) AS Status
  WHERE 1=0;
  RETURN;
END

SELECT
  @@SERVERNAME AS SqlServerName,
  p.id AS PackageId,
  p.name AS PackageName,
  f.foldername AS Folder,
  p.createdate AS CreatedDate,
  p.lastupdatedate AS LastModifiedDate,
  'OK' AS Status
FROM msdb.dbo.sysssispackages p
LEFT JOIN msdb.dbo.sysssispackagefolders f ON f.folderid = p.folderid
ORDER BY f.foldername, p.name;
"@

$mpAll=New-Object System.Collections.Generic.List[object]
$ssAll=New-Object System.Collections.Generic.List[object]

foreach($sv in $config.servers){
  $endpoint=[string]$sv.name
  $alias= if($sv.alias){[string]$sv.alias}else{$endpoint}
  try{
    $conn=New-ConnParamsFromConfig $sv $config

    foreach($r in (Invoke-Sqlcmd @conn -Query $qMP)){
      $mpAll.Add([pscustomobject]@{
        ServerAlias=$alias; ServerEndpoint=$endpoint; SqlServerName=$r.SqlServerName
        PlanId=$r.PlanId; PlanName=$r.PlanName; Description=$r.Description
        OwnerLogin=$r.OwnerLogin; CreateDate=$r.CreateDate; ModifyDate=$r.ModifyDate
      })|Out-Null
    }

    foreach($r in (Invoke-Sqlcmd @conn -Query $qSS)){
      $ssAll.Add([pscustomobject]@{
        ServerAlias=$alias; ServerEndpoint=$endpoint; SqlServerName=$r.SqlServerName
        PackageId=$r.PackageId; PackageName=$r.PackageName; Folder=$r.Folder
        CreatedDate=$r.CreatedDate; LastModifiedDate=$r.LastModifiedDate; Status=$r.Status
      })|Out-Null
    }

  } catch {
    Write-Warning "Błąd $endpoint: $($_.Exception.Message)"
  }
}

$mpAll | Sort-Object ServerAlias, PlanName | Export-Csv -LiteralPath $outMP -NoTypeInformation -Encoding UTF8
$ssAll | Sort-Object ServerAlias, Folder, PackageName | Export-Csv -LiteralPath $outSS -NoTypeInformation -Encoding UTF8

Write-Host "OK -> $outMP"
Write-Host "OK -> $outSS"
