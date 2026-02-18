/* Backup compliance — FULL/DIFF/LOG per database (SQL Server 2012+)
   Shows minutes since last backup by type.
*/
SET NOCOUNT ON;

;WITH b AS
(
    SELECT
        database_name,
        type,
        MAX(backup_finish_date) AS last_finish_date
    FROM msdb.dbo.backupset
    WHERE is_copy_only = 0
    GROUP BY database_name, type
)
SELECT
    d.name AS DatabaseName,
    d.state_desc,
    d.recovery_model_desc,
    bF.last_finish_date AS LastFull,
    DATEDIFF(MINUTE, bF.last_finish_date, SYSDATETIME()) AS MinutesSinceFull,
    bD.last_finish_date AS LastDiff,
    CASE WHEN bD.last_finish_date IS NULL THEN NULL ELSE DATEDIFF(MINUTE, bD.last_finish_date, SYSDATETIME()) END AS MinutesSinceDiff,
    bL.last_finish_date AS LastLog,
    CASE WHEN bL.last_finish_date IS NULL THEN NULL ELSE DATEDIFF(MINUTE, bL.last_finish_date, SYSDATETIME()) END AS MinutesSinceLog
FROM sys.databases d
LEFT JOIN b bF ON bF.database_name = d.name AND bF.type = 'D'
LEFT JOIN b bD ON bD.database_name = d.name AND bD.type = 'I'
LEFT JOIN b bL ON bL.database_name = d.name AND bL.type = 'L'
WHERE d.database_id > 4
ORDER BY
    CASE WHEN d.state_desc <> 'ONLINE' THEN 0 ELSE 1 END,
    d.name;
