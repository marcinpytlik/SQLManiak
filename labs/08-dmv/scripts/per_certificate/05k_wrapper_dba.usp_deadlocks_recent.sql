USE AdventureWorks2022;
GO
CREATE OR ALTER PROC dba.usp_deadlocks_recent
    @top int = 10
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @base_path nvarchar(260);

    SELECT @base_path =
        CAST(CAST(t.target_data AS xml).value('(/EventFileTarget/File/@name)[1]', 'nvarchar(260)') AS nvarchar(260))
    FROM sys.server_event_sessions AS s
    JOIN sys.server_event_session_targets AS t
      ON t.event_session_id = s.event_session_id
    WHERE s.name = N'system_health' AND t.target_name = N'event_file';

    IF @base_path IS NULL
    BEGIN
        -- fallback na domyślną ścieżkę logów
        DECLARE @logdir nvarchar(260) = REPLACE(CONVERT(nvarchar(260), SERVERPROPERTY('ErrorLogFileName')), N'ERRORLOG', N'');
        SET @base_path = @logdir + N'system_health*.xel';
    END
    ELSE
    BEGIN
        -- zamień ostatni numer na wildcard
        DECLARE @pos int = LEN(@base_path) - CHARINDEX('\', REVERSE(@base_path)) + 1;
        SET @base_path = LEFT(@base_path, @pos) + N'system_health*.xel';
    END

    ;WITH x AS (
        SELECT
            CAST(event_data AS xml) AS xdata
        FROM sys.fn_xe_file_target_read_file(@base_path, NULL, NULL, NULL)
        WHERE object_name = 'xml_deadlock_report'
    )
    SELECT TOP (@top)
        x.xdata.value('(/event/@timestamp)[1]', 'datetime2') AS ts_utc,
        x.xdata.value('(/event/data/value/deadlock)[1]', 'xml') AS deadlock_graph_xml
    FROM x
    ORDER BY ts_utc DESC;
END;
GO
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'dmv_cert')
BEGIN
    IF EXISTS (SELECT 1 FROM sys.crypt_properties WHERE major_id=OBJECT_ID(N'dba.usp_deadlocks_recent'))
        DROP SIGNATURE FROM OBJECT::dba.usp_deadlocks_recent BY CERTIFICATE dmv_cert;
    ADD SIGNATURE TO OBJECT::dba.usp_deadlocks_recent BY CERTIFICATE dmv_cert;
END
GO
GRANT EXECUTE ON dba.usp_deadlocks_recent TO [role_dmv_cert_readers];
GO
