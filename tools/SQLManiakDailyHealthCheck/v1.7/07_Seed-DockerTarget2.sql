/* Run on SQL Repository 15433 after 04_MonitoredServers.sql.
   Idempotently adds the second test target. Does NOT modify existing
   127.0.0.1,15434 or production inventory records. */
USE SQLManiakHealthHistory;
GO
IF OBJECT_ID(N'dhc.MonitoredServer',N'U') IS NULL
    THROW 51004, 'Run 04_MonitoredServers.sql first.', 1;
GO
IF NOT EXISTS (SELECT 1 FROM dhc.MonitoredServer WHERE ServerInstance=N'127.0.0.1,15435')
BEGIN
 INSERT dhc.MonitoredServer
 (ServerInstance,DisplayName,Environment,MonitorGroup,IsEnabled,IntervalMinutes,CollectTempDB,Notes)
 VALUES
 (N'127.0.0.1,15435',N'DHC Docker Target 2','LAB',N'Docker',1,1440,1,N'Multi-target failure isolation lab');
END
ELSE IF EXISTS (SELECT 1 FROM dhc.MonitoredServer
                WHERE ServerInstance=N'127.0.0.1,15435' AND Environment<>'LAB')
    THROW 51005, 'Endpoint 15435 exists outside LAB; manual review required.', 1;
ELSE
 UPDATE dhc.MonitoredServer SET IsEnabled=1,CollectTempDB=1
 WHERE ServerInstance=N'127.0.0.1,15435' AND Environment='LAB';

SELECT ServerId,ServerInstance,Environment,IsEnabled,CollectTempDB
FROM dhc.MonitoredServer
WHERE Environment='LAB'
ORDER BY ServerInstance;
GO
