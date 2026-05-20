USE [msdb];
GO

MERGE dbo.DBA_BackupDatabaseConfig AS target
USING
(
    VALUES
        (N'baza1', N'X:\backup', 1, 1, 1, 1, 10, N'Grupa X'),
        (N'baza2', N'X:\backup', 1, 1, 1, 1, 10, N'Grupa X'),
        (N'baza3', N'X:\backup', 1, 1, 1, 1, 10, N'Grupa X'),
        (N'baza5', N'Z:\backup', 1, 1, 1, 1, 20, N'Grupa Z'),
        (N'baza6', N'Z:\backup', 1, 1, 1, 1, 20, N'Grupa Z'),
        (N'baza7', N'Z:\backup', 1, 1, 1, 1, 20, N'Grupa Z'),
        (N'master', N'X:\backup', 1, 1, 0, 0, 1, N'Baza systemowa - tylko FULL'),
        (N'model',  N'X:\backup', 1, 1, 0, 0, 1, N'Baza systemowa - tylko FULL'),
        (N'msdb',   N'X:\backup', 1, 1, 0, 0, 1, N'Baza systemowa - tylko FULL')
) AS source(DatabaseName, BackupBasePath, IsEnabled, BackupFull, BackupDiff, BackupLog, Priority, Notes)
ON target.DatabaseName = source.DatabaseName
WHEN MATCHED THEN
    UPDATE SET
        BackupBasePath = source.BackupBasePath,
        IsEnabled = source.IsEnabled,
        BackupFull = source.BackupFull,
        BackupDiff = source.BackupDiff,
        BackupLog = source.BackupLog,
        Priority = source.Priority,
        Notes = source.Notes
WHEN NOT MATCHED THEN
    INSERT (DatabaseName, BackupBasePath, IsEnabled, BackupFull, BackupDiff, BackupLog, Priority, Notes)
    VALUES (source.DatabaseName, source.BackupBasePath, source.IsEnabled, source.BackupFull, source.BackupDiff, source.BackupLog, source.Priority, source.Notes);
GO

/* Generator brakujących wpisów - skopiuj wynik i przypisz X:\backup albo Z:\backup według potrzeb. */
SELECT
    d.name AS DatabaseName,
    SuggestedMergeRow = CONCAT(
        '(N''', REPLACE(d.name, '''', ''''''), ''', N''X:\backup'', 1, 1, 1, ',
        CASE WHEN d.recovery_model_desc = 'SIMPLE' THEN '0' ELSE '1' END,
        ', 100, N''TODO''),' )
FROM sys.databases AS d
WHERE
    d.state_desc = 'ONLINE'
    AND d.is_read_only = 0
    AND d.name <> N'tempdb'
    AND NOT EXISTS
    (
        SELECT 1
        FROM dbo.DBA_BackupDatabaseConfig AS c
        WHERE c.DatabaseName = d.name
    )
ORDER BY d.name;
GO

SELECT *
FROM dbo.DBA_BackupDatabaseConfig
ORDER BY Priority, DatabaseName;
GO
