/* ============================================================
   WHAT HAPPENED? – śledztwo dla okna czasowego
   Autor: SQLManiak
   ============================================================ */

SET NOCOUNT ON;

/* 0) USTAW PRZEDZIAŁ CZASU ---------------------------------- */
DECLARE @FromLocal  datetime2(0) = '2025-10-29 06:00:00';
DECLARE @ToLocal    datetime2(0) = '2025-10-29 06:30:00';

/* Wylicz UTC dla system_health (XE zapisuje w UTC) */
DECLARE @LocalToUtcOffsetMin int = DATEDIFF(MINUTE, GETDATE(), SYSUTCDATETIME());
DECLARE @FromUtc datetime2(0) = DATEADD(MINUTE, @LocalToUtcOffsetMin, @FromLocal);
DECLARE @ToUtc   datetime2(0) = DATEADD(MINUTE, @LocalToUtcOffsetMin, @ToLocal);

PRINT '=============================================';
PRINT ' 0) Okno analizy';
PRINT '---------------------------------------------';
SELECT @FromLocal AS FromLocal, @ToLocal AS ToLocal, @FromUtc AS FromUTC, @ToUtc AS ToUTC;


/* 1) ERROR LOG (błędy, restarty, I/O, autogrow) -------------- */
PRINT '=============================================';
PRINT ' 1) ERROR LOG (xp_readerrorlog)';
PRINT '---------------------------------------------';
BEGIN TRY
    DECLARE @LogNumber int = 0; -- 0 = bieżący; zmień na 1..N dla archiwów
    EXEC xp_readerrorlog @LogNumber, 1, NULL, NULL, @FromLocal, @ToLocal, N'desc';
END TRY
BEGIN CATCH
    SELECT 'xp_readerrorlog niedostępny lub brak uprawnień' AS Note,
           ERROR_NUMBER() AS ErrNo, ERROR_MESSAGE() AS ErrMsg;
END CATCH;


/* 2) SQL SERVER AGENT – historia jobów ----------------------- */
PRINT '=============================================';
PRINT ' 2) SQL Server Agent – msdb.dbo.sysjobhistory';
PRINT '---------------------------------------------';
;WITH H AS
(
    SELECT j.name AS JobName,
           CONVERT(datetime,
             STUFF(STUFF(RIGHT('000000'+CAST(run_date AS varchar(8)),8),5,0,'-'),8,0,'-')
             + ' ' +
             STUFF(STUFF(RIGHT('000000'+CAST(run_time AS varchar(6)),6),3,0,':'),6,0,':')
           ) AS RunDateTime,
           h.run_duration,
           CASE h.run_status
                WHEN 0 THEN 'Failed'
                WHEN 1 THEN 'Succeeded'
                WHEN 2 THEN 'Retry'
                WHEN 3 THEN 'Canceled'
                WHEN 4 THEN 'In-progress'
           END AS RunStatus,
           h.step_id, h.step_name, h.message
    FROM msdb.dbo.sysjobhistory h
    JOIN msdb.dbo.sysjobs j ON j.job_id = h.job_id
)
SELECT *
FROM H
WHERE RunDateTime >= @FromLocal AND RunDateTime < @ToLocal
ORDER BY RunDateTime DESC, JobName, step_id;


/* 3) DEFAULT TRACE – autogrow/shrink, loginy, zmiany obiektów - */
PRINT '=============================================';
PRINT ' 3) Default trace – autogrow, logins, DDL, ErrorLog';
PRINT '---------------------------------------------';
DECLARE @tracePath nvarchar(4000);

SELECT @tracePath =
  (SELECT REVERSE(SUBSTRING(REVERSE(path), CHARINDEX('\', REVERSE(path)), 4000)) + 'log.trc'
   FROM sys.traces WHERE is_default = 1);

IF @tracePath IS NOT NULL
BEGIN
    SELECT 
        TE.name AS EventName,
        t.StartTime,
        t.DatabaseName,
        t.FileName,
        t.TextData,
        t.LoginName,
        t.HostName,
        t.ApplicationName
    FROM fn_trace_gettable(@tracePath, DEFAULT) AS t
    JOIN sys.trace_events AS TE ON t.EventClass = TE.trace_event_id
    WHERE t.StartTime >= @FromLocal AND t.StartTime < @ToLocal
      AND TE.name IN
      (
          'Data File Auto Grow','Log File Auto Grow',
          'Data File Auto Shrink','Log File Auto Shrink',
          'Audit Login','Audit Logout',
          'Object:Created','Object:Deleted','Object:Altered',
          'ErrorLog'
      )
    ORDER BY t.StartTime DESC;
END
ELSE
BEGIN
    SELECT 'Default trace nieaktywny lub brak dostępu' AS Note;
END


/* 4) system_health (XE) – deadlocki, błędy, spille ------------ */
PRINT '=============================================';
PRINT ' 4) system_health (Extended Events) – deadlock, error_reported, attention, exchange_spill';
PRINT '---------------------------------------------';
BEGIN TRY
    DECLARE @xeBasePath nvarchar(4000);

    SELECT @xeBasePath =
      CAST(t.target_data AS xml).value('(/EventFileTarget/File/@name)[1]', 'nvarchar(4000)')
    FROM sys.dm_xe_session_targets t
    JOIN sys.dm_xe_sessions s ON t.event_session_address = s.address
    WHERE s.name = 'system_health' AND t.target_name = 'event_file';

    IF @xeBasePath IS NULL
    BEGIN
        SELECT 'Brak targetu event_file w system_health' AS Note;
    END
    ELSE
    BEGIN
        DECLARE @xeWildcard nvarchar(4000) = @xeBasePath + N'*'; -- zbierz wszystkie obroty pliku

        ;WITH X AS
        (
            SELECT CAST(event_data AS xml) AS ed
            FROM sys.fn_xe_file_target_read_file(@xeWildcard, NULL, NULL, NULL)
        )
        SELECT
            ed.value('(event/@name)[1]', 'sysname')                    AS event_name,
            ed.value('(event/@timestamp)[1]', 'datetime2')             AS utc_time,
            -- przybliżony czas lokalny:
            DATEADD(MINUTE, -@LocalToUtcOffsetMin,
                    ed.value('(event/@timestamp)[1]', 'datetime2'))    AS approx_local_time,
            ed.value('(event/data[@name="error"]/text)[1]', 'nvarchar(4000)') AS error_text,
            ed.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS sql_text,
            ed.query('.') AS event_xml
        FROM X
        WHERE ed.value('(event/@name)[1]', 'sysname') IN
              ('xml_deadlock_report','error_reported','attention','exchange_spill')
          AND ed.value('(event/@timestamp)[1]', 'datetime2') >= @FromUtc
          AND ed.value('(event/@timestamp)[1]', 'datetime2') <  @ToUtc
        ORDER BY approx_local_time DESC;
    END
END TRY
BEGIN CATCH
    SELECT 'system_health odczyt nieudany' AS Note,
           ERROR_NUMBER() AS ErrNo, ERROR_MESSAGE() AS ErrMsg;
END CATCH;


/* 5) BACKUP/RESTORE w oknie ----------------------------------- */
PRINT '=============================================';
PRINT ' 5) Backup/Restore wydarzenia';
PRINT '---------------------------------------------';

-- Backupy
SELECT TOP (500)
    b.database_name,
    b.type AS backup_type,   -- D=full, I=diff, L=log
    b.backup_start_date,
    b.backup_finish_date,
    DATEDIFF(second, b.backup_start_date, b.backup_finish_date) AS duration_s,
    b.first_lsn, b.last_lsn,
    b.server_name, b.machine_name
FROM msdb.dbo.backupset b
WHERE b.backup_start_date < @ToLocal
  AND b.backup_finish_date >= @FromLocal
ORDER BY b.backup_start_date DESC;

-- Restore
SELECT TOP (200)
    r.destination_database_name,
    r.user_name,
    r.restore_date,
    r.replace,
    r.recovery
FROM msdb.dbo.restorehistory r
WHERE r.restore_date >= @FromLocal AND r.restore_date < @ToLocal
ORDER BY r.restore_date DESC;


/* 6) AUTO-GROW/IO – szybki obraz plików (stan po fakcie) ------ */
PRINT '=============================================';
PRINT ' 6) IO/Pliki – sys.dm_io_virtual_file_stats (stan bieżący, nie historia)';
PRINT '---------------------------------------------';
SELECT TOP (200)
    DB_NAME(vfs.database_id) AS [database],
    mf.type_desc,
    mf.name,
    mf.physical_name,
    vfs.num_of_reads,
    vfs.num_of_writes,
    vfs.num_of_bytes_read,
    vfs.num_of_bytes_written,
    vfs.io_stall_read_ms,
    vfs.io_stall_write_ms,
    vfs.size_on_disk_bytes,
    vfs.sample_ms
FROM sys.dm_io_virtual_file_stats(NULL, NULL) vfs
JOIN sys.master_files mf
  ON mf.database_id = vfs.database_id AND mf.file_id = vfs.file_id
ORDER BY vfs.num_of_bytes_written DESC, vfs.num_of_writes DESC;


/* 7) LOGINY/POŁĄCZENIA – z default trace/error logu ------------ */
PRINT '=============================================';
PRINT ' 7) Loginy/Logouts – patrz sekcja 3 (Default Trace) i 1 (Error Log)';
PRINT '---------------------------------------------';
-- Wskazówka: w sekcji 3 są zdarzenia 'Audit Login' / 'Audit Logout'.
-- W Error Logu często widać awarie logowania / przerwy TLS / sieć.


/* 8) TEMPDB – szybki stan wykorzystania ----------------------- */
PRINT '=============================================';
PRINT ' 8) tempdb – rozmiary i wykorzystanie teraz (po fakcie)';
PRINT '---------------------------------------------';
USE tempdb;
SELECT
    name,
    type_desc,
    size_mb     = size * 1.0 / 128,
    used_mb     = FILEPROPERTY(name,'SpaceUsed') / 128.0,
    free_mb     = (size * 1.0 / 128) - (FILEPROPERTY(name,'SpaceUsed') / 128.0)
FROM sys.database_files
ORDER BY type_desc, name;

-- Powrót do master
USE master;
