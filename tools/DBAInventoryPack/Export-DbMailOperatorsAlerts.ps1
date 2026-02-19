[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ConfigPath)

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
. "$PSScriptRoot\SqlInventory.Helpers.ps1"
function Ensure-Folder([string]$Path){ Ensure-InvFolder -Path $Path }

Ensure-SqlServerModule
$config=(Get-Content -Raw -LiteralPath $ConfigPath) | ConvertFrom-Json
if(-not $config.options){ $config | Add-Member options ([pscustomobject]@{}) }
if($null -eq $config.options.commandTimeoutSeconds){ $config.options | Add-Member commandTimeoutSeconds 60 }
if(-not $config.output){ $config | Add-Member output ([pscustomobject]@{}) }
if(-not $config.output.folder){ $config.output | Add-Member folder "C:\temp\SqlInventory" }
Ensure-Folder $config.output.folder

$outMail = Join-Path $config.output.folder "sql-dbmail-config.csv"
$outOps  = Join-Path $config.output.folder "sql-agent-operators.csv"
$outAl   = Join-Path $config.output.folder "sql-agent-alerts.csv"

$qMail=@"
SET NOCOUNT ON;

SELECT
  @@SERVERNAME AS SqlServerName,
  'PROFILE' AS RowType,
  p.profile_id AS Id,
  p.name AS Name,
  p.description AS Description,
  NULL AS Extra1,
  NULL AS Extra2
FROM msdb.dbo.sysmail_profile p

UNION ALL

SELECT
  @@SERVERNAME AS SqlServerName,
  'ACCOUNT' AS RowType,
  a.account_id AS Id,
  a.name AS Name,
  a.description AS Description,
  a.email_address AS Extra1,
  a.display_name AS Extra2
FROM msdb.dbo.sysmail_account a

UNION ALL

SELECT
  @@SERVERNAME AS SqlServerName,
  'PROFILE_ACCOUNT' AS RowType,
  pa.profile_id AS Id,
  p.name AS Name,
  a.name AS Description,
  CAST(pa.sequence_number AS varchar(20)) AS Extra1,
  CAST(pa.is_default AS varchar(5)) AS Extra2
FROM msdb.dbo.sysmail_profileaccount pa
JOIN msdb.dbo.sysmail_profile p ON p.profile_id = pa.profile_id
JOIN msdb.dbo.sysmail_account a ON a.account_id = pa.account_id

UNION ALL

SELECT
  @@SERVERNAME AS SqlServerName,
  'SMTP_SERVER' AS RowType,
  s.account_id AS Id,
  a.name AS Name,
  s.servername AS Description,
  CAST(s.port AS varchar(20)) AS Extra1,
  CAST(s.enable_ssl AS varchar(5)) AS Extra2
FROM msdb.dbo.sysmail_server s
JOIN msdb.dbo.sysmail_account a ON a.account_id = s.account_id;
"@

$qOps=@"
SET NOCOUNT ON;
SELECT
  @@SERVERNAME AS SqlServerName,
  o.id AS OperatorId,
  o.name AS OperatorName,
  o.enabled AS Enabled,
  o.email_address AS Email,
  o.pager_address AS Pager,
  o.category_name AS CategoryName
FROM msdb.dbo.sysoperators o
ORDER BY o.name;
"@

$qAlerts=@"
SET NOCOUNT ON;
SELECT
  @@SERVERNAME AS SqlServerName,
  a.id AS AlertId,
  a.name AS AlertName,
  a.enabled AS Enabled,
  a.message_id AS MessageId,
  a.severity AS Severity,
  a.database_name AS DatabaseName,
  a.delay_between_responses AS DelayBetweenResponsesSeconds,
  a.include_event_description AS IncludeEventDescription,
  o.name AS NotifyOperator,
  ao.notification_method AS NotificationMethod,
  a.last_occurrence_date AS LastOccurrenceDate,
  a.last_occurrence_time AS LastOccurrenceTime
FROM msdb.dbo.sysalerts a
LEFT JOIN msdb.dbo.sysnotifications ao ON ao.alert_id = a.id
LEFT JOIN msdb.dbo.sysoperators o ON o.id = ao.operator_id
ORDER BY a.name;
"@

$mailAll=New-Object System.Collections.Generic.List[object]
$opsAll=New-Object System.Collections.Generic.List[object]
$alAll=New-Object System.Collections.Generic.List[object]

foreach($sv in $config.servers){
  $endpoint=[string]$sv.name
  $alias= if($sv.alias){[string]$sv.alias}else{$endpoint}
  try{
    $conn=New-ConnParamsFromConfig $sv $config

    foreach($r in (Invoke-Sqlcmd @conn -Query $qMail)){
      $mailAll.Add([pscustomobject]@{
        ServerAlias=$alias; ServerEndpoint=$endpoint; SqlServerName=$r.SqlServerName
        RowType=$r.RowType; Id=$r.Id; Name=$r.Name; Description=$r.Description; Extra1=$r.Extra1; Extra2=$r.Extra2
      })|Out-Null
    }

    foreach($r in (Invoke-Sqlcmd @conn -Query $qOps)){
      $opsAll.Add([pscustomobject]@{
        ServerAlias=$alias; ServerEndpoint=$endpoint; SqlServerName=$r.SqlServerName
        OperatorId=$r.OperatorId; OperatorName=$r.OperatorName; Enabled=$r.Enabled; Email=$r.Email; Pager=$r.Pager; CategoryName=$r.CategoryName
      })|Out-Null
    }

    foreach($r in (Invoke-Sqlcmd @conn -Query $qAlerts)){
      $alAll.Add([pscustomobject]@{
        ServerAlias=$alias; ServerEndpoint=$endpoint; SqlServerName=$r.SqlServerName
        AlertId=$r.AlertId; AlertName=$r.AlertName; Enabled=$r.Enabled
        MessageId=$r.MessageId; Severity=$r.Severity; DatabaseName=$r.DatabaseName
        DelayBetweenResponsesSeconds=$r.DelayBetweenResponsesSeconds
        IncludeEventDescription=$r.IncludeEventDescription
        NotifyOperator=$r.NotifyOperator
        NotificationMethod=$r.NotificationMethod
        LastOccurrenceDate=$r.LastOccurrenceDate
        LastOccurrenceTime=$r.LastOccurrenceTime
      })|Out-Null
    }

  } catch {
    Write-Warning "Błąd ${endpoint}: $($_.Exception.Message)"
  }
}

$mailAll | Sort-Object ServerAlias, RowType, Name | Export-Csv -LiteralPath $outMail -NoTypeInformation -Encoding UTF8
$opsAll  | Sort-Object ServerAlias, OperatorName | Export-Csv -LiteralPath $outOps  -NoTypeInformation -Encoding UTF8
$alAll   | Sort-Object 'ServerAlias', @{ Expression = 'Enabled'; Descending = $true }, 'AlertName' | Export-Csv -LiteralPath $outAl   -NoTypeInformation -Encoding UTF8

Write-Host "OK -> $outMail"
Write-Host "OK -> $outOps"
Write-Host "OK -> $outAl"
