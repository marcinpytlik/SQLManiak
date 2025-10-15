param(
  [string]$Primary = "SQLPROD01\INST1",
  [string]$Secondary = "SQLDR01\INST1",
  [string]$Db = "YourDB"
)

$tsqlPrimary = @"
SELECT 'primary' AS side, primary_database AS db, last_backup_date, last_backup_file
FROM msdb.dbo.log_shipping_monitor_primary WHERE primary_database = '$Db';
"@

$tsqlSecondary = @"
SELECT 'secondary' AS side, secondary_database AS db, last_copied_date, last_restored_date,
       last_copied_file, last_restored_file
FROM msdb.dbo.log_shipping_monitor_secondary WHERE secondary_database = '$Db';
"@

Invoke-Sqlcmd -S $Primary -Q $tsqlPrimary
Invoke-Sqlcmd -S $Secondary -Q $tsqlSecondary
