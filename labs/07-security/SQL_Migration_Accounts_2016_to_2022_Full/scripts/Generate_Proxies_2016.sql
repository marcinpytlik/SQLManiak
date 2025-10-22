
/* Generate_Proxies_2016.sql */
USE msdb;
SET NOCOUNT ON;

;WITH P AS (
    SELECT p.proxy_id, p.name, p.credential_id, p.is_enabled, p.description,
           c.name AS credential_name
    FROM msdb.dbo.sysproxies AS p
    LEFT JOIN master.sys.credentials AS c ON c.credential_id = p.credential_id
)
SELECT
    '-- Proxy: ' + QUOTENAME(P.name) + CHAR(10) +
    'IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysproxies WHERE name = N' + QUOTENAME(P.name,'''') + ')'+CHAR(10)+
    'BEGIN'+CHAR(10)+
    '    EXEC msdb.dbo.sp_add_proxy @proxy_name = N' + QUOTENAME(P.name,'''') + ','+CHAR(10)+
    '        @credential_name = N' + QUOTENAME(P.credential_name,'''') + ','+CHAR(10)+
    '        @enabled = ' + CAST(P.is_enabled AS varchar(10)) + ','+CHAR(10)+
    '        @description = N' + COALESCE(QUOTENAME(P.description, ''''), 'NULL') + ';'+CHAR(10)+
    'END'+CHAR(10)+
    'GO'+CHAR(10)+
    ISNULL( (
        SELECT STRING_AGG(CAST(
            'EXEC msdb.dbo.sp_grant_proxy_to_subsystem @proxy_name = N' + QUOTENAME(P.name,'''') +
            ', @subsystem_id = ' + CAST(pss.subsystem_id AS varchar(10)) + ';'
        AS nvarchar(max)), CHAR(10))
        FROM msdb.dbo.sysproxysubsystem AS pss WHERE pss.proxy_id = P.proxy_id
    , '') + CHAR(10) +
    ISNULL( (
        SELECT STRING_AGG(CAST(
            'EXEC msdb.dbo.sp_grant_login_to_proxy @proxy_name = N' + QUOTENAME(P.name,'''') +
            ', @login_name = N' + QUOTENAME(SUSER_SNAME(pl.sid),'''') + ';'
        AS nvarchar(max)), CHAR(10))
        FROM msdb.dbo.sysproxylogin AS pl WHERE pl.proxy_id = P.proxy_id
    , '') + CHAR(10)+
    'GO'+CHAR(10)
AS [-- Run on SQL 2022]
FROM P
ORDER BY P.name;
