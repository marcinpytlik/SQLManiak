#requires -Version 7.2
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$required=@(
    '01_Installation/34_Install-DHC-Repository.ps1',
    '01_Installation/35_Configure-DHC-Source.ps1',
    '01_Installation/37_Install-DHC-Repository-AllInOne.sql',
    '01_Installation/38_Configure-DHC-Source-AllInOne.sql',
    '01_Installation/39_Install-DHC-AutogrowthXE-AllInOne.sql',
    '02_Repository/01_Repository.sql',
    '02_Repository/04_MonitoredServers.sql',
    '02_Repository/08_ExecutionLog.sql',
    '02_Repository/09_MonitoringStatus.sql',
    '02_Repository/12_TryStartExecution.sql',
    '02_Repository/14_RunningWatch.sql',
    '02_Repository/20_RepositoryLeastPrivilege.sql',
    '02_Repository/42_CapacityRepository.sql',
    '02_Repository/44_CapacityForecast.sql',
    '02_Repository/49_LinkedServerReports.sql',
    '03_Collector/02_TempDB_Collect.sql',
    '03_Collector/03_Run-DHC-v1_7.ps1',
    '03_Collector/06_Run-DHC-MonitoredServers.ps1',
    '03_Collector/43_CapacityCollect.sql',
    '03_Collector/47_LinkedServerCollect.sql',
    '03_Collector/48_LinkedServerConnectivity.sql',
    '03_Collector/SQLManiak_Daily_Health_Check_v1_5_CSV.sql',
    '04_Configuration/16_Save-DHC-SchedulerConfig.ps1',
    '04_Configuration/17_Invoke-DHC-Scheduled.ps1',
    '05_Validation/21_Test-SchedulerIdentity.ps1',
    '05_Validation/24_Audit-SourceSqlPermissions.ps1',
    '05_Validation/40_Validate-DHC-Source-XE-Deployment.sql',
    '06_Reporting/10_MonitoringStatus_Checks.sql',
    '06_Reporting/36_GrafanaPortalReader.sql',
    '06_Reporting/45_CapacityChecks.sql',
    '06_Reporting/50_LinkedServerChecks.sql',
    '07_Documentation/38_Configure-DHC-Source-AllInOne.md',
    '07_Documentation/41_PRODUCTION_XE_DEPLOYMENT.md',
    '07_Documentation/ARCHITECTURE.md',
    '07_Documentation/PRODUCTION_DEPLOYMENT.md',
    '07_Documentation/SOURCE_SQL_AUDIT.md',
    'README.md',
    '.gitattributes',
    '.gitignore'
)
$missing=@($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $root $_) -PathType Leaf) })
if($missing.Count){throw ('Missing package files: '+($missing -join ', '))}
$baseline=Join-Path $root '03_Collector/SQLManiak_Daily_Health_Check_v1_5_CSV.sql'
$expected='8978B06A630F24D672EDD78721B1B8A4A84DD6CCC724B9B87DF4DBB847DA67B8'
$actual=(Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash
if($actual -ne $expected){throw "Baseline SQL SHA256 mismatch: $actual"}
$parseIssues=@(foreach($file in $required | Where-Object { $_ -like '*.ps1' }){
    $tokens=$null; $errors=$null
    $null=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root $file),[ref]$tokens,[ref]$errors)
    foreach($issue in $errors){ "$file : $($issue.Message)" }
})
if($parseIssues.Count){throw ('PowerShell parse errors: '+($parseIssues -join '; '))}
[pscustomobject]@{Status='PASS';Root=$root;RequiredFiles=$required.Count;BaselineSHA256=$actual;PowerShellSyntax='PASS';RuntimeTested=$false}
