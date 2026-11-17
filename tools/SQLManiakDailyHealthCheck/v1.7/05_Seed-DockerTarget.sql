/* DHC v1.7: register and enable the known Docker target.
   Run on SQL Repository 127.0.0.1,15433 after 04_MonitoredServers.sql.
   Idempotent. Only touches the one LAB record named below.
   No credentials, scheduled tasks, or changes on the monitored target.
*/
USE SQLManiakHealthHistory;
GO
IF OBJECT_ID(N'dhc.MonitoredServer', N'U') IS NULL
    THROW 51002, 'Missing dhc.MonitoredServer; run 04_MonitoredServers.sql first.', 1;
GO
IF NOT EXISTS
(
 SELECT 1 FROM dhc.MonitoredServer
 WHERE ServerInstance=N'127.0.0.1,15434'
)
BEGIN
 INSERT dhc.MonitoredServer
   (ServerInstance,DisplayName,Environment,MonitorGroup,
    IsEnabled,IntervalMinutes,CollectTempDB,Notes)
 VALUES
   (N'127.0.0.1,15434',N'DHC Docker Target','LAB',N'Docker',
    1,1440,1,N'Local SQL Server 2022 test target; enabled for manual runner tests');
END
ELSE
BEGIN
 -- Do not overwrite an existing record from a different environment.
 IF EXISTS (SELECT 1 FROM dhc.MonitoredServer
            WHERE ServerInstance=N'127.0.0.1,15434' AND Environment<>'LAB')
     THROW 51003, 'Existing endpoint is not labeled LAB. Manual review required.', 1;
 UPDATE dhc.MonitoredServer
 SET IsEnabled=1,CollectTempDB=1
 WHERE ServerInstance=N'127.0.0.1,15434' AND Environment='LAB';
END;

SELECT ServerId,ServerInstance,DisplayName,Environment,MonitorGroup,
       IsEnabled,IntervalMinutes,CollectTempDB
FROM dhc.MonitoredServer
WHERE ServerInstance=N'127.0.0.1,15434';
GO
