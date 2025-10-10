
-- scripts/Test-Kerberos.sql
SELECT
    @@SERVERNAME            AS [ServerName],
    SUSER_SNAME()           AS [ExecutionContext],
    CONVERT(sysname, SERVERPROPERTY('ComputerNamePhysicalNetBIOS')) AS [OwnerNode],
    c.auth_scheme           AS [AuthScheme],
    c.protocol_type         AS [Protocol],
    c.net_transport         AS [NetTransport],
    c.local_net_address     AS [LocalAddress],
    c.local_tcp_port        AS [LocalPort]
FROM sys.dm_exec_connections AS c
WHERE c.session_id = @@SPID;

-- oczekiwane: AuthScheme = KERBEROS
