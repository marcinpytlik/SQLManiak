/*
 SQLManiak DHC v1.7 - SQL-ONLY SOURCE INSTANCE INSTALLER (SQL Server 2022+)
 Run this ON EACH MONITORED SQL SERVER INSTANCE, not on the central Repository.
 SSMS / T-SQL only. No PowerShell, SQLCMD mode, or supplementary files.
 Mirrors source-side grants from 35_Configure-DHC-Source.ps1.

 PRE-FLIGHT: configure @ExpectedServer to exact SELECT @@SERVERNAME;
 provide @Password ONLY when creating new SQL login. Keep real passwords
 in a private local copy, NEVER commit them to GitHub, paste into tickets
 or include in logs. Connect with a deployment DBA authorized for CREATE LOGIN,
 GRANT server permissions and msdb role changes.

 INSTALLS:
 - SQL login [dhc_source_collector] (created only when absent)
 - VIEW SERVER PERFORMANCE STATE, VIEW SERVER SECURITY STATE, VIEW ANY ERROR LOG
 - VIEW ANY DEFINITION (required for sys.master_files metadata visibility)
 - msdb user mapped to login and membership in SQLAgentReaderRole
 - msdb.dhc_agent_history_reader with SELECT on four agent tables
 - legacy optional server role dhc_autogrowth_reader with ALTER TRACE (off by default;
   do NOT enable for XE-based collectors). XE session is installed separately by 39.

 DOES NOT:
 - create SQLManiakHealthHistory, configure the Repository, change any user DB,
   install SQL Agent jobs, change recovery model, start collections or touch data.
 - reset existing login passwords, revoke previous permissions or change
   application/operating system logins.
 - grant sysadmin, db_owner or db_datareader.
 - revoke legacy grants from pre-existing principals (audit separately).

 On FCI, @@SERVERNAME is the SQL instance name; run once per SQL instance,
 not once per cluster node. Review account/password policy and ALTER TRACE with
 bank security; SQL Server 2016/2019 require a separate installer/review.
*/
USE master;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- ====== CONFIGURATION: edit in a PRIVATE local copy ======
DECLARE @ExpectedServer sysname = N'REPLACE_WITH_EXACT_AT_AT_SERVERNAME';
DECLARE @Password nvarchar(128) = N'REPLACE_WITH_STRONG_SOURCE_PASSWORD_16_PLUS';
DECLARE @GrantAlterTrace bit = 0;  -- optional, broad permission; disabled by default
DECLARE @Login sysname = N'dhc_source_collector';

-- ====== PRE-FLIGHT: fail BEFORE any changes ======
IF CONVERT(int,SERVERPROPERTY('ProductMajorVersion')) < 16
    THROW 51800, 'SQL Server 2022+ is required. Use separate review for 2016/2019.', 1;
IF @ExpectedServer IS NULL OR @ExpectedServer LIKE N'REPLACE_WITH_%'
   OR @ExpectedServer <> CONVERT(sysname,@@SERVERNAME)
    THROW 51801, 'Wrong target SQL Server. Set @ExpectedServer to exact SELECT @@SERVERNAME.', 1;
IF DB_ID(N'msdb') IS NULL
    THROW 51802, 'msdb database is not accessible.', 1;
IF @GrantAlterTrace NOT IN (0,1) OR @GrantAlterTrace IS NULL
    THROW 51803, 'Invalid ALTER TRACE choice.', 1;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name=@Login AND type <> 'S')
    THROW 51804, 'Existing DHC principal is not a SQL login.', 1;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name=@Login)
   AND ISNULL(IS_SRVROLEMEMBER(N'sysadmin',@Login),0) <> 0
    THROW 51805, 'Existing DHC login is sysadmin; refusing to reuse.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name=@Login)
   AND (@Password IS NULL OR @Password LIKE N'REPLACE_WITH_%' OR LEN(@Password)<16)
    THROW 51806, 'Set a strong source login password (16+ chars) in a private local copy.', 1;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name=N'dhc_autogrowth_reader' AND type<>'R')
   AND @GrantAlterTrace=1
    THROW 51807, 'Existing dhc_autogrowth_reader principal is not a server role.', 1;

-- Verify msdb principals BEFORE creating anything.
USE msdb;
IF EXISTS (
 SELECT 1 FROM sys.database_principals
 WHERE name=N'dhc_source_collector'
   AND (type<>'S' OR SUSER_SID(N'dhc_source_collector') IS NULL
        OR sid<>SUSER_SID(N'dhc_source_collector'))
)
    THROW 51808, 'msdb user name exists but does not map to the expected SQL login.', 1;
IF EXISTS (
 SELECT 1 FROM sys.database_principals
 WHERE name=N'dhc_agent_history_reader' AND type<>'R'
)
    THROW 51809, 'msdb.dhc_agent_history_reader exists and is not a role.', 1;
IF DATABASE_PRINCIPAL_ID(N'SQLAgentReaderRole') IS NULL
    THROW 51810, 'msdb.SQLAgentReaderRole not found.', 1;

USE master;
-- ====== INSTALL SQL LOGIN & SERVER PERMISSIONS ======
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name=@Login)
BEGIN
    DECLARE @CreateSql nvarchar(max) =
      N'CREATE LOGIN [dhc_source_collector] WITH PASSWORD = N''' +
      REPLACE(@Password,N'''',N'''''') +
      N''', CHECK_POLICY = ON, CHECK_EXPIRATION = OFF, DEFAULT_DATABASE = [master];';
    EXEC sys.sp_executesql @CreateSql;
    SET @CreateSql=NULL;
    PRINT 'Created new SQL login dhc_source_collector.';
END
ELSE
    PRINT 'Existing login dhc_source_collector retained. Password not changed.';

SET @Password=NULL;
GRANT VIEW SERVER PERFORMANCE STATE TO [dhc_source_collector];
GRANT VIEW SERVER SECURITY STATE TO [dhc_source_collector];
GRANT VIEW ANY ERROR LOG TO [dhc_source_collector];
-- SQL Server 2022: required to list database files from master.sys.master_files.
-- Metadata visibility is instance-wide; approved for the DHC deployment.
GRANT VIEW ANY DEFINITION TO [dhc_source_collector];

IF @GrantAlterTrace=1
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name=N'dhc_autogrowth_reader')
        EXEC(N'CREATE SERVER ROLE [dhc_autogrowth_reader] AUTHORIZATION [sa];');
    GRANT ALTER TRACE TO [dhc_autogrowth_reader];
    IF NOT EXISTS (
       SELECT 1 FROM sys.server_role_members m
       JOIN sys.server_principals r ON r.principal_id=m.role_principal_id
       JOIN sys.server_principals u ON u.principal_id=m.member_principal_id
       WHERE r.name=N'dhc_autogrowth_reader' AND u.name=N'dhc_source_collector'
    )
        ALTER SERVER ROLE [dhc_autogrowth_reader] ADD MEMBER [dhc_source_collector];
    PRINT 'Optional ALTER TRACE granted via dhc_autogrowth_reader (review required).';
END
ELSE
    PRINT 'ALTER TRACE not requested. Existing grants, if any, are NOT revoked.';

-- ====== msdb: SQL Agent monitoring ======
USE msdb;
IF DATABASE_PRINCIPAL_ID(N'dhc_source_collector') IS NULL
    EXEC(N'CREATE USER [dhc_source_collector] FOR LOGIN [dhc_source_collector];');
IF DATABASE_PRINCIPAL_ID(N'dhc_agent_history_reader') IS NULL
    EXEC(N'CREATE ROLE [dhc_agent_history_reader] AUTHORIZATION [dbo];');

GRANT SELECT ON OBJECT::dbo.sysjobschedules TO [dhc_agent_history_reader];
GRANT SELECT ON OBJECT::dbo.sysjobhistory TO [dhc_agent_history_reader];
GRANT SELECT ON OBJECT::dbo.sysjobs TO [dhc_agent_history_reader];
GRANT SELECT ON OBJECT::dbo.sysjobactivity TO [dhc_agent_history_reader];
-- Required by the DHC v1.5 SQL Agent scheduling and job history checks.
GRANT SELECT ON OBJECT::dbo.sysschedules TO [dhc_agent_history_reader];
GRANT EXECUTE ON OBJECT::dbo.agent_datetime TO [dhc_agent_history_reader];

IF NOT EXISTS (
    SELECT 1 FROM sys.database_role_members m
    JOIN sys.database_principals r ON r.principal_id=m.role_principal_id
    JOIN sys.database_principals u ON u.principal_id=m.member_principal_id
    WHERE r.name=N'SQLAgentReaderRole' AND u.name=N'dhc_source_collector'
)
    ALTER ROLE [SQLAgentReaderRole] ADD MEMBER [dhc_source_collector];

IF NOT EXISTS (
    SELECT 1 FROM sys.database_role_members m
    JOIN sys.database_principals r ON r.principal_id=m.role_principal_id
    JOIN sys.database_principals u ON u.principal_id=m.member_principal_id
    WHERE r.name=N'dhc_agent_history_reader' AND u.name=N'dhc_source_collector'
)
    ALTER ROLE [dhc_agent_history_reader] ADD MEMBER [dhc_source_collector];

-- ====== VERIFICATION ======
SELECT @@SERVERNAME AS InstalledOnInstance,
       CONVERT(varchar(128),SERVERPROPERTY('ProductVersion')) AS ProductVersion,
       N'dhc_source_collector' AS SqlLogin,
       SUSER_SID(N'dhc_source_collector') AS LoginSID,
       ISNULL(IS_SRVROLEMEMBER(N'sysadmin',N'dhc_source_collector'),0) AS IsSysadmin;

SELECT p.permission_name,p.state_desc
FROM master.sys.server_permissions AS p
JOIN master.sys.server_principals AS s ON p.grantee_principal_id=s.principal_id
WHERE s.name=N'dhc_source_collector'
ORDER BY p.permission_name;

SELECT r.name AS MsdbRole,u.name AS MsdbUser
FROM sys.database_role_members AS m
JOIN sys.database_principals r ON m.role_principal_id=r.principal_id
JOIN sys.database_principals u ON m.member_principal_id=u.principal_id
WHERE u.name=N'dhc_source_collector'
ORDER BY r.name;
PRINT 'DHC source permissions (including VIEW ANY DEFINITION) complete. Run a real DHC collection as the least-privileged identity to validate runtime access.';
GO
