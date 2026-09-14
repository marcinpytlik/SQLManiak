param(
    [string]$ServerInstance = 'sql64',
    [string]$SqlUser,
    [SecureString]$SqlPassword
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
. (Join-Path $root 'POC.Common.ps1')

Write-PocStep "Stage 1 - SQL Server CDC on $ServerInstance"

$files = @(
    '00_CreateDatabase.sql',
    '01_CreateTables.sql',
    '02_EnableCDC.sql',
    '03_GenerateData.sql',
    '04_ReadChanges.sql',
    '05_CDC_Monitoring.sql',
    '06_CDC_Retention.sql'
)

foreach ($file in $files) {
    Write-PocStep "Executing $file"
    Invoke-PocSqlFile -ServerInstance $ServerInstance -Path (Join-Path $root $file) -SqlUser $SqlUser -SqlPassword $SqlPassword
}

Write-PocStep 'Stage 1 verification'
$query = @"
SET NOCOUNT ON;
USE CDC_Lab;
SELECT DB_NAME() AS DatabaseName,
       (SELECT is_cdc_enabled FROM sys.databases WHERE database_id = DB_ID()) AS IsCdcEnabled;
SELECT name, is_tracked_by_cdc
FROM sys.tables
WHERE name IN (N'Customer', N'CustomerOrder');
SELECT capture_instance, filegroup_name, supports_net_changes
FROM cdc.change_tables;
EXEC sys.sp_cdc_help_jobs;
"@
Invoke-PocQuery -ServerInstance $ServerInstance -Query $query -SqlUser $SqlUser -SqlPassword $SqlPassword

Write-PocPass 'Stage 1 completed. Review the verification output above before moving to Stage 2.'
