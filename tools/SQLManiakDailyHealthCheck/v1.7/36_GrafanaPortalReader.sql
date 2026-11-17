/*
 SQLManiak DHC Portal MVP - read-only Grafana access.
 Execute on Repository as deployment administrator.
 Expects an EXISTING SQL login (create it separately using a secure password).
 Replace exact login below. Never reuse the collector login.
 No broad schema SELECT and no write permissions.
*/
USE SQLManiakHealthHistory;
GO
SET NOCOUNT ON;
DECLARE @Login sysname=N'dhc_grafana_reader';
IF SCHEMA_ID(N'dhc') IS NULL OR OBJECT_ID(N'dhc.vMonitoringStatus',N'V') IS NULL
    THROW 51600,'Install DHC Repository first.',1;
IF SUSER_ID(@Login) IS NULL
    THROW 51601,'SQL login dhc_grafana_reader is missing; create it securely first.',1;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name=N'dhc_portal_reader' AND type<>'R')
    THROW 51602,'Principal dhc_portal_reader exists with incompatible type.',1;
IF DATABASE_PRINCIPAL_ID(N'dhc_portal_reader') IS NULL
    EXEC(N'CREATE ROLE [dhc_portal_reader] AUTHORIZATION [dbo];');
IF DATABASE_PRINCIPAL_ID(@Login) IS NULL
    EXEC(N'CREATE USER [dhc_grafana_reader] FOR LOGIN [dhc_grafana_reader];');
GO
GRANT SELECT ON OBJECT::dhc.MonitoredServer TO [dhc_portal_reader];
GRANT SELECT ON OBJECT::dhc.ExecutionLog TO [dhc_portal_reader];
GRANT SELECT ON OBJECT::dhc.Run TO [dhc_portal_reader];
GRANT SELECT ON OBJECT::dhc.Alert TO [dhc_portal_reader];
GRANT SELECT ON OBJECT::dhc.vMonitoringStatus TO [dhc_portal_reader];
GRANT SELECT ON OBJECT::dhc.vMonitoringSummary TO [dhc_portal_reader];
GO
IF NOT EXISTS
(
 SELECT 1 FROM sys.database_role_members rm
 JOIN sys.database_principals r ON r.principal_id=rm.role_principal_id
 JOIN sys.database_principals u ON u.principal_id=rm.member_principal_id
 WHERE r.name=N'dhc_portal_reader' AND u.name=N'dhc_grafana_reader'
)
 ALTER ROLE [dhc_portal_reader] ADD MEMBER [dhc_grafana_reader];
GO
SELECT r.name AS RoleName,u.name AS MemberName
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id=rm.role_principal_id
JOIN sys.database_principals u ON u.principal_id=rm.member_principal_id
WHERE r.name=N'dhc_portal_reader';
GO
/* Audit separately: do not grant db_datareader, dhc_collector, db_owner, sysadmin.
   Connect AS dhc_grafana_reader to verify 9 panel queries in Grafana.
   The portal account may read diagnostic alerts, which can include sensitive
   object names and error text. Limit Grafana access accordingly.
*/
