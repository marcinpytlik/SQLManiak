/* SQLManiak DHC v1.7 - repository least-privilege ROLE only.
   Run on LAB Repository after 01,04,08,09,12,14.
   Does NOT create SQL logins or attach users automatically.
   Grants to exact objects; does not grant db_owner/db_datawriter/sysadmin.
   Review for production before use.
*/
USE SQLManiakHealthHistory;
GO
SET NOCOUNT ON;
IF SCHEMA_ID(N'dhc') IS NULL
    THROW 51100,'Missing dhc schema. Deploy DHC repository first.',1;
IF OBJECT_ID(N'dhc.TryStartExecution',N'P') IS NULL
    THROW 51101,'Missing due-aware claim procedure (12).',1;
IF OBJECT_ID(N'dhc.MonitoredServer',N'U') IS NULL
 OR OBJECT_ID(N'dhc.ExecutionLog',N'U') IS NULL
 OR OBJECT_ID(N'dhc.Run',N'U') IS NULL
 OR OBJECT_ID(N'dhc.ResultBatch',N'U') IS NULL
 OR OBJECT_ID(N'dhc.Alert',N'U') IS NULL
 OR OBJECT_ID(N'dhc.TempDBSnapshot',N'U') IS NULL
 OR OBJECT_ID(N'dhc.TempDBFile',N'U') IS NULL
 OR OBJECT_ID(N'dhc.TempDBSession',N'U') IS NULL
    THROW 51102,'Missing one or more DHC repository tables.',1;
GO
IF DATABASE_PRINCIPAL_ID(N'dhc_collector') IS NULL
    CREATE ROLE dhc_collector AUTHORIZATION dbo;
GO
-- Inventory + preview scheduling reads.
GRANT SELECT ON OBJECT::dhc.MonitoredServer TO dhc_collector;
GRANT SELECT ON OBJECT::dhc.ExecutionLog TO dhc_collector;
GRANT EXECUTE ON OBJECT::dhc.TryStartExecution TO dhc_collector;

-- Record the non-atomic runner completion/failure in ExecutionLog.
GRANT INSERT, UPDATE ON OBJECT::dhc.ExecutionLog TO dhc_collector;

-- One collection transaction: write Run and its detail/alert tables.
GRANT INSERT, UPDATE ON OBJECT::dhc.Run TO dhc_collector;
-- UPDATE ... WHERE RunId=@RunId requires SELECT permission on predicate column.
-- Column-only grant avoids exposing other fields of dhc.Run.
GRANT SELECT ON OBJECT::dhc.Run (RunId) TO dhc_collector;
GRANT INSERT ON OBJECT::dhc.ResultBatch TO dhc_collector;
GRANT INSERT ON OBJECT::dhc.Alert TO dhc_collector;
GRANT INSERT ON OBJECT::dhc.TempDBSnapshot TO dhc_collector;
GRANT INSERT ON OBJECT::dhc.TempDBFile TO dhc_collector;
GRANT INSERT ON OBJECT::dhc.TempDBSession TO dhc_collector;
-- Capacity metrics are append-only; volume policy remains DBA-managed.
GRANT INSERT ON OBJECT::dhc.CapacityFileSample TO dhc_collector;
GRANT INSERT ON OBJECT::dhc.CapacityLogSample TO dhc_collector;
GRANT SELECT ON OBJECT::dhc.VolumeCapacityPolicy TO dhc_collector;
GO
-- Role grants audit: should NOT show CONTROL, ALTER, DELETE, db_owner.
SELECT
    dp.name AS RoleName,
    o.name AS ObjectName,
    p.permission_name AS PermissionName,
    p.state_desc AS PermissionState
FROM sys.database_permissions AS p
JOIN sys.database_principals AS dp ON p.grantee_principal_id=dp.principal_id
LEFT JOIN sys.objects AS o ON p.major_id=o.object_id
WHERE dp.name=N'dhc_collector'
ORDER BY o.name,p.permission_name;
GO
/* ACCOUNT PROVISIONING (MANUAL / NOT EXECUTED):
   1. In Docker LAB only, create dedicated server SQL login with a strong
      independently generated secret kept outside Git and the chat.
   2. Map that login to a user in SQLManiakHealthHistory.
   3. ALTER ROLE dhc_collector ADD MEMBER [YOUR_LAB_DHC_USER];
   4. Use its credential for repository DPAPI config in a NEW private folder.
   5. Do not reuse sa and do not grant server-wide roles or db_owner.
   Exact source-server permissions are outside scope: v1.5 original is
   local and may invoke privileged diagnostic stored procedures.
*/
