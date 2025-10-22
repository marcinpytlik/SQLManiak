
/* Generate_LinkedServers_2016.sql */
SET NOCOUNT ON;

;WITH S AS (
    SELECT s.server_id, s.name, s.product, s.provider, s.data_source, s.provider_string, s.catalog,
           s.is_linked, s.is_remote_login_enabled, s.is_rpc_out_enabled, s.is_data_access_enabled,
           s.is_collation_compatible, s.connect_timeout, s.query_timeout, s.is_remote_proc_transaction_promotion_enabled
    FROM sys.servers AS s
    WHERE s.is_linked = 1
)
SELECT
    '-- Linked server: ' + QUOTENAME(S.name) + CHAR(10) +
    'IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = N' + QUOTENAME(S.name,'''') + ')'+CHAR(10)+
    'BEGIN'+CHAR(10)+
    '    EXEC sys.sp_addlinkedserver '+CHAR(10)+
    '        @server = N' + QUOTENAME(S.name,'''') + ','+CHAR(10)+
    '        @srvproduct = ' + COALESCE(QUOTENAME(S.product, ''''), 'N''''') + ','+CHAR(10)+
    '        @provider = ' + COALESCE(QUOTENAME(S.provider, ''''), 'NULL') + ','+CHAR(10)+
    '        @datasrc = ' + COALESCE(QUOTENAME(S.data_source, ''''), 'NULL') + ','+CHAR(10)+
    '        @provstr = ' + COALESCE(QUOTENAME(S.provider_string, ''''), 'NULL') + ','+CHAR(10)+
    '        @catalog = ' + COALESCE(QUOTENAME(S.catalog, ''''), 'NULL') + ';'+CHAR(10)+
    'END'+CHAR(10)+
    'GO'+CHAR(10)+
    'EXEC sys.sp_serveroption @server=N' + QUOTENAME(S.name,'''') + ', @optname=N''data access'', @optvalue=''' + CASE WHEN S.is_data_access_enabled=1 THEN 'true' ELSE 'false' END + ''';'+CHAR(10)+
    'EXEC sys.sp_serveroption @server=N' + QUOTENAME(S.name,'''') + ', @optname=N''rpc out'', @optvalue=''' + CASE WHEN S.is_rpc_out_enabled=1 THEN 'true' ELSE 'false' END + ''';'+CHAR(10)+
    'EXEC sys.sp_serveroption @server=N' + QUOTENAME(S.name,'''') + ', @optname=N''collation compatible'', @optvalue=''' + CASE WHEN S.is_collation_compatible=1 THEN 'true' ELSE 'false' END + ''';'+CHAR(10)+
    'EXEC sys.sp_serveroption @server=N' + QUOTENAME(S.name,'''') + ', @optname=N''remote proc transaction promotion'', @optvalue=''' + CASE WHEN S.is_remote_proc_transaction_promotion_enabled=1 THEN 'true' ELSE 'false' END + ''';'+CHAR(10)+
    ISNULL((
        SELECT STRING_AGG(CAST(
            'EXEC sys.sp_addlinkedsrvlogin @rmtsrvname = N' + QUOTENAME(S.name,'''') +
            ', @useself = ' + CASE WHEN ll.uses_self=1 THEN 'N''TRUE''' ELSE 'N''FALSE''' END +
            CASE WHEN ll.local_principal_id IS NULL THEN ', @locallogin = NULL' ELSE ', @locallogin = ' + QUOTENAME(SUSER_SNAME(ll.local_principal_id),'''') END +
            CASE WHEN ll.uses_self=1 THEN '' ELSE ', @rmtuser = N''' + REPLACE(COALESCE(ll.remote_name,''),'''','''''') + ''', @rmtpassword = N''<<FILL_PASSWORD>>''' END + ';'
        AS nvarchar(max)), CHAR(10))
        FROM sys.linked_logins AS ll WHERE ll.server_id = S.server_id
    ), '') + CHAR(10) +
    'GO'+CHAR(10)
AS [-- Run on SQL 2022]
FROM S
ORDER BY S.name;
