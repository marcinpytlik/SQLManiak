/* scripts/02_Verify.sql */
SELECT @@SERVERNAME                    AS RuntimeName,
       SERVERPROPERTY('ServerName')    AS ServerPropertyName,
       SERVERPROPERTY('MachineName')   AS OSHost,
       SERVERPROPERTY('InstanceName')  AS InstanceName;
GO

SELECT server_id, name, data_source
FROM sys.servers
ORDER BY server_id;  -- 0 = local
