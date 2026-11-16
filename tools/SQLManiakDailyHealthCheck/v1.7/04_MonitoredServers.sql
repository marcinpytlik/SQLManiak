/* SQLManiak DHC v1.7 - monitored SQL Server instances inventory.
   Run on SQL Repository (port 15433 in the Docker lab).
   Safe to rerun; no existing DHC history or configuration is altered.
   Does NOT create credentials or schedule the collector.
*/
USE SQLManiakHealthHistory;
GO
IF SCHEMA_ID(N'dhc') IS NULL
    THROW 51001, 'Schema dhc is missing. Run 01_Repository.sql first.', 1;
GO

IF OBJECT_ID(N'dhc.MonitoredServer', N'U') IS NULL
BEGIN
    CREATE TABLE dhc.MonitoredServer
    (
        ServerId int IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_DHCMonitoredServer PRIMARY KEY,
        ServerInstance nvarchar(256) NOT NULL,
        DisplayName nvarchar(256) NULL,
        Environment varchar(12) NOT NULL,
        MonitorGroup nvarchar(80) NULL,
        IsEnabled bit NOT NULL
            CONSTRAINT DF_DHCMonitoredServer_IsEnabled DEFAULT (0),
        IntervalMinutes int NOT NULL
            CONSTRAINT DF_DHCMonitoredServer_IntervalMinutes DEFAULT (1440),
        CollectTempDB bit NOT NULL
            CONSTRAINT DF_DHCMonitoredServer_CollectTempDB DEFAULT (1),
        Notes nvarchar(1000) NULL,
        CreatedUTC datetime2(3) NOT NULL
            CONSTRAINT DF_DHCMonitoredServer_CreatedUTC DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_DHCMonitoredServer_ServerInstance UNIQUE (ServerInstance),
        CONSTRAINT CK_DHCMonitoredServer_Instance_NotBlank CHECK (LEN(LTRIM(RTRIM(ServerInstance))) > 0),
        CONSTRAINT CK_DHCMonitoredServer_Environment
            CHECK (Environment IN ('PROD','TEST','DEV','LAB','DR')),
        CONSTRAINT CK_DHCMonitoredServer_IntervalMinutes
            CHECK (IntervalMinutes BETWEEN 1 AND 10080)
    );
END;
GO

-- The inventory is configuration, not history: intentionally no foreign key
-- from dhc.Run.ServerInstance, so historical runs remain when inventory changes.
SELECT ServerId, ServerInstance, DisplayName, Environment, MonitorGroup,
       IsEnabled, IntervalMinutes, CollectTempDB, Notes, CreatedUTC
FROM dhc.MonitoredServer
ORDER BY Environment, ServerInstance;
GO

/* Example: insert the local Docker target ONCE, if desired.
   Disabled by default; enable only after configuring a scheduler.

IF NOT EXISTS (
    SELECT 1 FROM dhc.MonitoredServer
    WHERE ServerInstance = N'127.0.0.1,15434'
)
BEGIN
    INSERT dhc.MonitoredServer
        (ServerInstance, DisplayName, Environment, MonitorGroup,
         IsEnabled, IntervalMinutes, CollectTempDB, Notes)
    VALUES
        (N'127.0.0.1,15434', N'DHC Docker Target', 'LAB', N'Docker',
         0, 1440, 1, N'Local SQL Server 2022 test instance');
END;

-- Example production registration (replace values with real endpoints).
-- Keep IsEnabled = 0 until tested with a least-privilege collector identity.
-- INSERT dhc.MonitoredServer(ServerInstance, DisplayName, Environment, MonitorGroup, IsEnabled)
-- VALUES (N'FCI-VNN\INST', N'Production SQL FCI', 'PROD', N'Cluster-01', 0);

-- Enable monitoring for a verified endpoint (no schedule is installed here).
-- UPDATE dhc.MonitoredServer SET IsEnabled = 1
-- WHERE ServerInstance = N'FCI-VNN\INST';
*/
