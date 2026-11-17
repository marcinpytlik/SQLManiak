/* SQLManiak DHC v1.7 - durable multi-server runner execution history.
   Run on Repository (SQLManiakHealthHistory) AFTER 04_MonitoredServers.sql.
   Additive and idempotent; no existing DHC data is removed.
   Never log passwords, credentials, or connection strings.
*/
USE SQLManiakHealthHistory;
GO
IF OBJECT_ID(N'dhc.MonitoredServer', N'U') IS NULL
    THROW 51010, 'Run 04_MonitoredServers.sql before 08_ExecutionLog.sql.', 1;
GO
IF OBJECT_ID(N'dhc.ExecutionLog', N'U') IS NULL
BEGIN
 CREATE TABLE dhc.ExecutionLog
 (
    ExecutionId uniqueidentifier NOT NULL CONSTRAINT PK_DHCExecutionLog PRIMARY KEY,
    ServerId int NOT NULL,
    ServerInstance nvarchar(256) NOT NULL,
    StartedUTC datetime2(3) NOT NULL,
    FinishedUTC datetime2(3) NULL,
    Status varchar(16) NOT NULL,
    RunId uniqueidentifier NULL,
    RowsStored bigint NULL,
    ErrorText nvarchar(4000) NULL,
    RunnerVersion varchar(16) NOT NULL
        CONSTRAINT DF_DHCExecutionLog_RunnerVersion DEFAULT ('1.7'),
    CONSTRAINT CK_DHCExecutionLog_Status
        CHECK (Status IN ('RUNNING','COMPLETE','PARTIAL','FAILED')),
    CONSTRAINT CK_DHCExecutionLog_Finish
        CHECK (
            (Status='RUNNING' AND FinishedUTC IS NULL)
            OR (Status<>'RUNNING' AND FinishedUTC IS NOT NULL)
        ),
    CONSTRAINT CK_DHCExecutionLog_RunId
        CHECK ((Status IN ('RUNNING','FAILED') AND RunId IS NULL)
            OR (Status IN ('COMPLETE','PARTIAL') AND RunId IS NOT NULL))
 );
END;
GO
IF NOT EXISTS
(
 SELECT 1 FROM sys.indexes
 WHERE object_id=OBJECT_ID(N'dhc.ExecutionLog')
   AND name=N'IX_DHCExecutionLog_ServerStarted'
)
 CREATE INDEX IX_DHCExecutionLog_ServerStarted
 ON dhc.ExecutionLog(ServerInstance,StartedUTC DESC)
 INCLUDE(Status,FinishedUTC,RunId,RowsStored);
GO
IF NOT EXISTS
(
 SELECT 1 FROM sys.indexes
 WHERE object_id=OBJECT_ID(N'dhc.ExecutionLog')
   AND name=N'IX_DHCExecutionLog_StatusStarted'
)
 CREATE INDEX IX_DHCExecutionLog_StatusStarted
 ON dhc.ExecutionLog(Status,StartedUTC DESC)
 INCLUDE(ServerId,ServerInstance,FinishedUTC);
GO
SELECT TOP(20) ExecutionId,ServerId,ServerInstance,StartedUTC,FinishedUTC,
               Status,RunId,RowsStored,ErrorText
FROM dhc.ExecutionLog
ORDER BY StartedUTC DESC;
GO
