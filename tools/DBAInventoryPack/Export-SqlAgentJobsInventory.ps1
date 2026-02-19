<#
.SYNOPSIS
  Eksportuje inventory SQL Agent Jobs do CSV na podstawie config.json.

.REQUIREMENTS
  - Windows PowerShell 5.1+ lub PowerShell 7+
  - Moduł SqlServer (Invoke-Sqlcmd)

.USAGE
  .\Export-SqlAgentJobsInventory.ps1 -ConfigPath .\config.json
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$ConfigPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Folder {
  param([Parameter(Mandatory=$true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Ensure-SqlServerModule {
  if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    throw "Brak modułu 'SqlServer'. Zainstaluj: Install-Module SqlServer -Scope CurrentUser"
  }
}

function New-ConnParamsFromConfig {
  param(
    [Parameter(Mandatory=$true)][pscustomobject]$ServerCfg,
    [Parameter(Mandatory=$true)][pscustomobject]$RootCfg
  )

  $p = @{
    ServerInstance  = [string]$ServerCfg.name
    Database        = "msdb"
    QueryTimeout    = [int]$RootCfg.options.commandTimeoutSeconds
    ErrorAction     = "Stop"
  }

  if ($null -ne $ServerCfg.encrypt) { $p.Encrypt = [bool]$ServerCfg.encrypt }
  if ($null -ne $ServerCfg.trustServerCertificate) { $p.TrustServerCertificate = [bool]$ServerCfg.trustServerCertificate }

  switch ($RootCfg.auth.mode) {
    "Windows" { }
    "SqlLogin" {
      if (-not $RootCfg.auth.user -or -not $RootCfg.auth.password) {
        throw "auth.mode=SqlLogin wymaga auth.user i auth.password."
      }
      $sec = ConvertTo-SecureString $RootCfg.auth.password -AsPlainText -Force
      $p.Username = [string]$RootCfg.auth.user
      $p.Password = $sec
    }
    default { throw "Nieznany auth.mode: $($RootCfg.auth.mode). Użyj: Windows albo SqlLogin." }
  }

  return $p
}

Ensure-SqlServerModule

if (-not (Test-Path -LiteralPath $ConfigPath)) {
  throw "Nie znaleziono configu: $ConfigPath"
}

$config = (Get-Content -LiteralPath $ConfigPath -Raw) | ConvertFrom-Json

# Defaults
if (-not $config.options) { $config | Add-Member -NotePropertyName options -NotePropertyValue ([pscustomobject]@{}) }
if ($null -eq $config.options.commandTimeoutSeconds) { $config.options | Add-Member commandTimeoutSeconds 60 }
if (-not $config.output) { $config | Add-Member -NotePropertyName output -NotePropertyValue ([pscustomobject]@{}) }
if (-not $config.output.folder) { $config.output | Add-Member folder "C:\temp\SqlInventory" }
if (-not $config.output.fileNameJobs) { $config.output | Add-Member fileNameJobs "sql-agent-jobs-inventory.csv" }
if ($null -eq $config.output.perServerCsv) { $config.output | Add-Member perServerCsv $false }

Ensure-Folder -Path $config.output.folder

$logPath = Join-Path $config.output.folder ("jobs-inventory-log-{0}.txt" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
Start-Transcript -Path $logPath | Out-Null

# Query: 1 wiersz = 1 krok joba (job + step + schedule summary)
# Dzięki temu w CSV masz i job-level i step-level informacje bez osobnych plików.
$query = @"
SET NOCOUNT ON;

;WITH SchedAgg AS (
  SELECT
    js.job_id,
    ScheduleCount = COUNT(*),
    Schedules = STRING_AGG(s.name, '; ') WITHIN GROUP (ORDER BY s.name),
    HasEnabledSchedule = MAX(CASE WHEN s.enabled = 1 THEN 1 ELSE 0 END)
  FROM dbo.sysjobschedules js
  JOIN dbo.sysschedules s
    ON s.schedule_id = js.schedule_id
  GROUP BY js.job_id
),
Notify AS (
  SELECT
    j.job_id,
    EmailOperator = o.name,
    NotifyLevelEmail = j.notify_level_email,
    NotifyLevelPage  = j.notify_level_page,
    NotifyLevelNetSend = j.notify_level_netsend,
    NotifyLevelEventLog = j.notify_level_eventlog
  FROM dbo.sysjobs j
  LEFT JOIN dbo.sysoperators o
    ON o.id = j.notify_email_operator_id
)
SELECT
  @@SERVERNAME AS SqlServerName,

  j.job_id AS JobId,
  j.name AS JobName,
  j.enabled AS JobEnabled,
  j.description AS JobDescription,
  SUSER_SNAME(j.owner_sid) AS JobOwnerLogin,
  CONVERT(varchar(130), j.owner_sid, 1) AS JobOwnerSidHex,

  c.name AS JobCategory,
  j.date_created AS JobDateCreated,
  j.date_modified AS JobDateModified,
  j.version_number AS JobVersion,

  CASE j.start_step_id WHEN 0 THEN 1 ELSE j.start_step_id END AS StartStepId,

  -- Schedules (agregat)
  ISNULL(sa.ScheduleCount, 0) AS ScheduleCount,
  ISNULL(sa.Schedules, '') AS Schedules,
  ISNULL(sa.HasEnabledSchedule, 0) AS HasEnabledSchedule,

  -- Notifications
  ISNULL(n.EmailOperator, '') AS EmailOperator,
  n.NotifyLevelEmail,
  n.NotifyLevelPage,
  n.NotifyLevelNetSend,
  n.NotifyLevelEventLog,

  -- Step info (1 wiersz na krok)
  s.step_id AS StepId,
  s.step_name AS StepName,
  s.subsystem AS StepSubsystem,
  s.database_name AS StepDatabaseName,
  s.on_success_action AS StepOnSuccessAction,
  s.on_fail_action AS StepOnFailAction,
  s.retry_attempts AS StepRetryAttempts,
  s.retry_interval AS StepRetryIntervalMinutes,
  s.output_file_name AS StepOutputFile,
  s.last_run_outcome AS StepLastRunOutcome,
  s.last_run_date AS StepLastRunDate,
  s.last_run_time AS StepLastRunTime,
  s.last_run_duration AS StepLastRunDuration,
  LEFT(REPLACE(REPLACE(s.command, CHAR(13), ' '), CHAR(10), ' '), 4000) AS StepCommand_Trim4000

FROM dbo.sysjobs j
LEFT JOIN dbo.syscategories c
  ON c.category_id = j.category_id AND c.category_class = 1
LEFT JOIN SchedAgg sa
  ON sa.job_id = j.job_id
LEFT JOIN Notify n
  ON n.job_id = j.job_id
LEFT JOIN dbo.sysjobsteps s
  ON s.job_id = j.job_id
ORDER BY
  @@SERVERNAME, j.name, s.step_id;
"@

$all = New-Object System.Collections.Generic.List[object]

foreach ($sv in $config.servers) {
  $serverEndpoint = [string]$sv.name
  $alias = if ($sv.alias) { [string]$sv.alias } else { $serverEndpoint }

  Write-Host ("==> [{0}] Pobieram joby..." -f $serverEndpoint)

  try {
    $conn = New-ConnParamsFromConfig -ServerCfg $sv -RootCfg $config
    $rows = Invoke-Sqlcmd @conn -Query $query

    foreach ($r in $rows) {
      $jobOwner = [string]$r.JobOwnerLogin
      $jobOwnerSidHex = [string]$r.JobOwnerSidHex

      $ownerStatus =
        if ([string]::IsNullOrWhiteSpace($jobOwner)) { "ALERT:orphaned_sid" }
        else { "OK" }

      $recOwner =
        if ($config.policy -and $config.policy.recommendedJobOwner) { [string]$config.policy.recommendedJobOwner }
        else { "sa" }

      $isOwnerRecommended =
        (-not [string]::IsNullOrWhiteSpace($jobOwner)) -and ($jobOwner -ieq $recOwner)

      $obj = [PSCustomObject]@{
        ServerAlias    = $alias
        ServerEndpoint = $serverEndpoint
        SqlServerName  = $r.SqlServerName

        JobId          = $r.JobId
        JobName        = $r.JobName
        JobEnabled     = $r.JobEnabled
        JobDescription = $r.JobDescription
        JobCategory    = $r.JobCategory
        JobDateCreated = $r.JobDateCreated
        JobDateModified= $r.JobDateModified
        JobVersion     = $r.JobVersion
        StartStepId    = $r.StartStepId

        JobOwnerLogin  = $jobOwner
        JobOwnerSidHex = $jobOwnerSidHex
        JobOwnerStatus = $ownerStatus

        RecommendedJobOwner = $recOwner
        IsJobOwnerRecommended = $isOwnerRecommended
        JobOwnerActionHint = if ($isOwnerRecommended) { "OK" } else { "Consider: EXEC msdb.dbo.sp_update_job @job_name=N'$($r.JobName.Replace("'","''"))', @owner_login_name=N'$recOwner';" }

        ScheduleCount  = $r.ScheduleCount
        Schedules      = $r.Schedules
        HasEnabledSchedule = $r.HasEnabledSchedule

        EmailOperator  = $r.EmailOperator
        NotifyLevelEmail    = $r.NotifyLevelEmail
        NotifyLevelPage     = $r.NotifyLevelPage
        NotifyLevelNetSend  = $r.NotifyLevelNetSend
        NotifyLevelEventLog = $r.NotifyLevelEventLog

        StepId         = $r.StepId
        StepName       = $r.StepName
        StepSubsystem  = $r.StepSubsystem
        StepDatabaseName = $r.StepDatabaseName
        StepRetryAttempts = $r.StepRetryAttempts
        StepRetryIntervalMinutes = $r.StepRetryIntervalMinutes
        StepOnSuccessAction = $r.StepOnSuccessAction
        StepOnFailAction    = $r.StepOnFailAction
        StepOutputFile = $r.StepOutputFile
        StepLastRunOutcome = $r.StepLastRunOutcome
        StepLastRunDate = $r.StepLastRunDate
        StepLastRunTime = $r.StepLastRunTime
        StepLastRunDuration = $r.StepLastRunDuration
        StepCommand_Trim4000 = $r.StepCommand_Trim4000
      }

      $all.Add($obj) | Out-Null
    }

    if ([bool]$config.output.perServerCsv) {
      $safe = ($alias -replace '[^\w\.-]', '_')
      $perPath = Join-Path $config.output.folder ("sql-agent-jobs-inventory-{0}.csv" -f $safe)
      $all | Where-Object { $_.ServerAlias -eq $alias } |
        Sort-Object JobOwnerStatus, JobEnabled, JobName, StepId |
        Export-Csv -LiteralPath $perPath -NoTypeInformation -Encoding UTF8
      Write-Host ("    -> Zapisano per-serwer CSV: {0}" -f $perPath)
    }

    Write-Host ("    OK: {0} wierszy (job×steps)" -f ($rows.Count))
  }
  catch {
    Write-Warning ("    BŁĄD na serwerze [{0}]: {1}" -f $serverEndpoint, $_.Exception.Message)
    continue
  }
}

$outPath = Join-Path $config.output.folder $config.output.fileNameJobs

# Najpierw orphaned owner, potem disabled joby, potem reszta
$all |
  Sort-Object JobOwnerStatus, JobEnabled, ServerAlias, JobName, StepId |
  Export-Csv -LiteralPath $outPath -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host ("Zbiorczy CSV: {0}" -f $outPath)
Write-Host ("Log (transcript): {0}" -f $logPath)

Stop-Transcript | Out-Null
